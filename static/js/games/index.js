const byId = (id) => document.getElementById(id);

const MAX_VISIBLE_GAMES = 25;
const MAX_CONCURRENT_GAMES = 6;
const MAX_TEAM_RESULTS = 12;

const els = {
  status: byId("games-status"),
  refresh: byId("refresh-games"),
  newGameButton: byId("new-game-button"),
  newGamePanel: byId("new-game-panel"),
  cancelNewGame: byId("cancel-new-game"),
  newGameForm: byId("new-game-form"),
  gameName: byId("game-name"),
  homeSearch: byId("home-team-search"),
  awaySearch: byId("away-team-search"),
  homeId: byId("home-team-id"),
  awayId: byId("away-team-id"),
  homeSelected: byId("home-team-selected"),
  awaySelected: byId("away-team-selected"),
  homeResults: byId("home-team-results"),
  awayResults: byId("away-team-results"),
  createSubmit: byId("create-game-submit"),
  newGameError: byId("new-game-error"),
  newGameSuccess: byId("new-game-success"),
  list: byId("games-list"),
  empty: byId("games-empty"),
  error: byId("games-error"),
  total: byId("summary-total"),
  active: byId("summary-active"),
  completed: byId("summary-completed"),
  template: byId("game-card-template"),
};

const state = {
  teams: [],
  teamMap: new Map(),
  selectedHomeId: null,
  selectedAwayId: null,
  creatingGame: false,
};

function setStatus(label, status) {
  els.status.textContent = label;
  els.status.dataset.state = status;
}

async function api(path, options = {}) {
  const {
    method = "GET",
    payload = null,
    allow404 = false,
  } = options;

  const headers = {
    "Accept": "application/json",
  };

  let body;

  if (payload !== null) {
    headers["Content-Type"] = "application/json";
    body = JSON.stringify(payload);
  }

  const response = await fetch(path, {
    method,
    headers,
    body,
    cache: "no-store",
  });

  if (allow404 && response.status === 404) {
    return null;
  }

  if (!response.ok) {
    let detail = "";

    try {
      const errorBody = await response.json();
      detail =
        typeof errorBody?.detail === "string"
          ? errorBody.detail
          : JSON.stringify(errorBody?.detail || "");
    } catch (_) {
      // Fall through to generic status text.
    }

    throw new Error(
      detail
        ? `${path} returned HTTP ${response.status}: ${detail}`
        : `${path} returned HTTP ${response.status}`,
    );
  }

  return response.json();
}

function phaseLabel(value) {
  const phase = String(value || "not_initialized");

  const labels = {
    pregame: "Pregame",
    first_half: "1st Half",
    halftime: "Halftime",
    second_half: "2nd Half",
    full_time: "Full Time",
    not_initialized: "Not Initialized",
  };

  return labels[phase] || phase.replaceAll("_", " ");
}

function clockLabel(clock) {
  if (!clock) return "Clock Not Initialized";

  const status = String(clock.status || "unknown").replaceAll("_", " ");

  const seconds = Number(
    clock.display_seconds
    ?? clock.authoritative_elapsed_seconds
    ?? 0,
  );

  const safe = Number.isFinite(seconds)
    ? Math.max(0, Math.floor(seconds))
    : 0;

  const minutes = Math.floor(safe / 60);
  const remainder = safe % 60;

  return `${status} · ${minutes}:${String(remainder).padStart(2, "0")}`;
}

function isCompleted(game, lifecycle) {
  return (
    lifecycle?.phase === "full_time"
    || game?.status === "completed"
  );
}

function isActive(game, lifecycle, clock) {
  if (isCompleted(game, lifecycle)) return false;

  return (
    ["first_half", "halftime", "second_half"].includes(lifecycle?.phase)
    || clock?.status === "running"
    || game?.status === "live"
  );
}

function gameSortValue(game) {
  const raw =
    game.scheduled_at
    || game.updated_at
    || game.created_at
    || "";

  const value = Date.parse(raw);

  return Number.isFinite(value) ? value : 0;
}

function buildTeamMap(teams) {
  const map = new Map();

  for (const team of teams) {
    map.set(String(team.id), team);
  }

  return map;
}

function getTeamFromMap(teamId, fallbackName) {
  return (
    state.teamMap.get(String(teamId))
    || {
      id: teamId,
      name: fallbackName,
      short_name: fallbackName,
    }
  );
}

async function safeGetOptional(path, label) {
  try {
    return await api(path, { allow404: true });
  } catch (error) {
    console.warn(
      `M12-C optional ${label} lookup failed: ${path}`,
      error,
    );

    return null;
  }
}

async function hydrateGame(game) {
  const [lifecycle, clock] = await Promise.all([
    safeGetOptional(
      `/api/games/${game.id}/lifecycle`,
      "lifecycle",
    ),
    safeGetOptional(
      `/api/games/${game.id}/clock`,
      "clock",
    ),
  ]);

  return {
    game,
    homeTeam: getTeamFromMap(game.home_team_id, "HOME"),
    awayTeam: getTeamFromMap(game.away_team_id, "AWAY"),
    lifecycle,
    clock,
  };
}

function renderCard(item) {
  const { game, homeTeam, awayTeam, lifecycle, clock } = item;

  const fragment = els.template.content.cloneNode(true);
  const card = fragment.querySelector(".game-card");

  card.dataset.gameId = game.id;

  fragment.querySelector(".game-name").textContent =
    game.name || "Untitled Game";

  fragment.querySelector(".game-phase").textContent =
    phaseLabel(lifecycle?.phase);

  fragment.querySelector(".game-clock").textContent =
    clockLabel(clock);

  fragment.querySelector(".home-team-name").textContent =
    homeTeam?.short_name || homeTeam?.name || "HOME";

  fragment.querySelector(".away-team-name").textContent =
    awayTeam?.short_name || awayTeam?.name || "AWAY";

  fragment.querySelector(".home-score").textContent =
    String(game.home_score ?? 0);

  fragment.querySelector(".away-score").textContent =
    String(game.away_score ?? 0);

  fragment.querySelector(".game-id").textContent = game.id;

  fragment.querySelector(".control-link").href =
    `/control/games/${game.id}`;

  const overlay = fragment.querySelector(".overlay-link");
  overlay.href = `/overlay/games/${game.id}`;

  return fragment;
}

function renderSummary(allGames, visibleItems) {
  els.total.textContent = String(allGames.length);

  els.active.textContent = String(
    visibleItems.filter(({ game, lifecycle, clock }) =>
      isActive(game, lifecycle, clock)
    ).length,
  );

  els.completed.textContent = String(
    visibleItems.filter(({ game, lifecycle }) =>
      isCompleted(game, lifecycle)
    ).length,
  );
}

async function mapWithConcurrency(items, limit, worker) {
  const results = new Array(items.length);
  let nextIndex = 0;

  async function runWorker() {
    while (true) {
      const index = nextIndex;
      nextIndex += 1;

      if (index >= items.length) return;

      try {
        results[index] =
          await worker(items[index], index);
      } catch (error) {
        console.error(
          `M12-C hydration failed for item ${index}`,
          error,
        );

        results[index] = null;
      }
    }
  }

  const workerCount = Math.min(limit, items.length);

  await Promise.all(
    Array.from(
      { length: workerCount },
      () => runWorker(),
    ),
  );

  return results;
}

function showRecentGamesNotice(totalGames, visibleGames) {
  if (totalGames <= visibleGames) return;

  els.error.textContent =
    `Showing the ${visibleGames} most recent games `
    + `of ${totalGames} total. `
    + "Older historical/test games are not loaded into this view.";

  els.error.classList.remove("hidden");
}

function teamSearchText(team) {
  return [
    team.name,
    team.short_name,
  ]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();
}

function filteredTeams(query) {
  const normalized = String(query || "").trim().toLowerCase();

  const candidates = normalized
    ? state.teams.filter(
        (team) => teamSearchText(team).includes(normalized),
      )
    : state.teams;

  return candidates
    .slice()
    .sort((a, b) =>
      String(a.name || "").localeCompare(String(b.name || "")),
    )
    .slice(0, MAX_TEAM_RESULTS);
}

function selectedTeamId(side) {
  return side === "home"
    ? state.selectedHomeId
    : state.selectedAwayId;
}

function otherSelectedTeamId(side) {
  return side === "home"
    ? state.selectedAwayId
    : state.selectedHomeId;
}

function teamResultButton(team, side) {
  const button = document.createElement("button");

  button.type = "button";
  button.className = "team-search-result";
  button.dataset.teamId = team.id;
  button.setAttribute("role", "option");
  button.setAttribute(
    "aria-selected",
    String(String(selectedTeamId(side)) === String(team.id)),
  );

  const name = document.createElement("span");
  name.className = "team-result-name";
  name.textContent = team.name || team.short_name || "Unnamed Team";

  const shortName = document.createElement("span");
  shortName.className = "team-result-short";
  shortName.textContent = team.short_name || "";

  button.append(name, shortName);

  button.addEventListener("click", () => {
    selectTeam(side, team.id);
  });

  return button;
}

function renderTeamResults(side) {
  const input = side === "home"
    ? els.homeSearch
    : els.awaySearch;

  const results = side === "home"
    ? els.homeResults
    : els.awayResults;

  const teams = filteredTeams(input.value);
  const otherId = otherSelectedTeamId(side);

  results.replaceChildren();

  const visible = teams.filter(
    (team) => String(team.id) !== String(otherId || ""),
  );

  if (visible.length === 0) {
    const empty = document.createElement("div");
    empty.className = "team-search-empty";
    empty.textContent = "No matching teams.";
    results.appendChild(empty);
    return;
  }

  for (const team of visible) {
    results.appendChild(teamResultButton(team, side));
  }
}

function selectedTeamLabel(teamId) {
  const team = state.teamMap.get(String(teamId));

  if (!team) return "Not selected";

  return team.short_name
    ? `${team.name} (${team.short_name})`
    : team.name;
}

function selectTeam(side, teamId) {
  const otherId = otherSelectedTeamId(side);

  if (String(teamId) === String(otherId || "")) {
    showNewGameError(
      "Home and Away Team must be different.",
    );
    return;
  }

  if (side === "home") {
    state.selectedHomeId = String(teamId);
    els.homeId.value = String(teamId);
    els.homeSelected.textContent = selectedTeamLabel(teamId);
  } else {
    state.selectedAwayId = String(teamId);
    els.awayId.value = String(teamId);
    els.awaySelected.textContent = selectedTeamLabel(teamId);
  }

  clearNewGameMessages();

  renderTeamResults("home");
  renderTeamResults("away");
}

function clearTeamSelection() {
  state.selectedHomeId = null;
  state.selectedAwayId = null;

  els.homeId.value = "";
  els.awayId.value = "";

  els.homeSelected.textContent = "Not selected";
  els.awaySelected.textContent = "Not selected";

  els.homeSearch.value = "";
  els.awaySearch.value = "";

  renderTeamResults("home");
  renderTeamResults("away");
}

function clearNewGameMessages() {
  els.newGameError.classList.add("hidden");
  els.newGameSuccess.classList.add("hidden");
}

function showNewGameError(message) {
  els.newGameSuccess.classList.add("hidden");
  els.newGameError.textContent = message;
  els.newGameError.classList.remove("hidden");
}

function showNewGameSuccess(message) {
  els.newGameError.classList.add("hidden");
  els.newGameSuccess.textContent = message;
  els.newGameSuccess.classList.remove("hidden");
}

function setCreatingGame(value) {
  state.creatingGame = value;
  els.createSubmit.disabled = value;
  els.cancelNewGame.disabled = value;
  els.newGameButton.disabled = value;
  els.createSubmit.textContent =
    value ? "Creating + Initializing..." : "Create Game";
}

function openNewGamePanel() {
  clearNewGameMessages();
  els.newGamePanel.classList.remove("hidden");
  renderTeamResults("home");
  renderTeamResults("away");

  window.requestAnimationFrame(() => {
    els.gameName.focus();
  });
}

function closeNewGamePanel() {
  if (state.creatingGame) return;

  els.newGamePanel.classList.add("hidden");
  els.newGameForm.reset();
  clearTeamSelection();
  clearNewGameMessages();
}

function validateNewGame() {
  const name = els.gameName.value.trim();

  if (!name) {
    return "Game Name is required.";
  }

  if (!state.selectedHomeId) {
    return "Select a Home Team.";
  }

  if (!state.selectedAwayId) {
    return "Select an Away Team.";
  }

  if (state.selectedHomeId === state.selectedAwayId) {
    return "Home and Away Team must be different.";
  }

  return null;
}

async function ensureLifecycleInitialized(gameId) {
  const existing = await api(
    `/api/games/${gameId}/lifecycle`,
    { allow404: true },
  );

  if (existing) {
    return existing;
  }

  return api(
    `/api/games/${gameId}/lifecycle`,
    {
      method: "POST",
      payload: {},
    },
  );
}

async function ensureClockInitialized(gameId) {
  const existing = await api(
    `/api/games/${gameId}/clock`,
    { allow404: true },
  );

  if (existing) {
    return existing;
  }

  return api(
    `/api/games/${gameId}/clock`,
    {
      method: "POST",
      payload: {
        mode: "count_up",
        duration_seconds: 2700,
      },
    },
  );
}

async function initializeCreatedGame(game) {
  const lifecycle = await ensureLifecycleInitialized(game.id);
  const clock = await ensureClockInitialized(game.id);

  const [
    verifiedLifecycle,
    verifiedClock,
  ] = await Promise.all([
    api(`/api/games/${game.id}/lifecycle`),
    api(`/api/games/${game.id}/clock`),
  ]);

  if (verifiedLifecycle?.phase !== "pregame") {
    throw new Error(
      `Game ${game.name} was created, but lifecycle initialization did not verify as pregame.`,
    );
  }

  if (verifiedClock?.status === "running") {
    throw new Error(
      `Game ${game.name} was created, but the initialized clock unexpectedly started running.`,
    );
  }

  if (verifiedClock?.mode !== "count_up") {
    throw new Error(
      `Game ${game.name} was created, but the initialized clock is not count-up.`,
    );
  }

  if (Number(verifiedClock?.duration_seconds) !== 2700) {
    throw new Error(
      `Game ${game.name} was created, but the initialized clock duration is not 2700 seconds.`,
    );
  }

  return {
    lifecycle: verifiedLifecycle || lifecycle,
    clock: verifiedClock || clock,
  };
}

async function createGame(event) {
  event.preventDefault();

  if (state.creatingGame) return;

  const validationError = validateNewGame();

  if (validationError) {
    showNewGameError(validationError);
    return;
  }

  clearNewGameMessages();
  setCreatingGame(true);

  let game = null;

  try {
    game = await api("/api/games", {
      method: "POST",
      payload: {
        name: els.gameName.value.trim(),
        home_team_id: state.selectedHomeId,
        away_team_id: state.selectedAwayId,
      },
    });

    await initializeCreatedGame(game);

    showNewGameSuccess(
      `Game ready: ${game.name}. Pregame lifecycle and match clock are initialized.`,
    );

    els.newGameForm.reset();
    clearTeamSelection();

    await loadGames({
      preserveCreationMessages: true,
    });
  } catch (error) {
    console.error("M12-C Game creation / initialization failed", error);

    if (game?.id) {
      showNewGameError(
        `Game "${game.name}" was created, but match initialization did not complete. `
        + `Game ID: ${game.id}. `
        + `${error?.message || "Initialization failed."}`,
      );
    } else {
      showNewGameError(
        error?.message || "Game creation failed.",
      );
    }

    await loadGames({
      preserveCreationMessages: true,
    });
  } finally {
    setCreatingGame(false);
  }
}

async function loadGames(options = {}) {
  const {
    preserveCreationMessages = false,
  } = options;

  setStatus("LOADING", "loading");
  els.refresh.disabled = true;
  els.error.classList.add("hidden");

  if (!preserveCreationMessages) {
    clearNewGameMessages();
  }

  try {
    const [games, teams] = await Promise.all([
      api("/api/games"),
      api("/api/teams"),
    ]);

    state.teams = teams;
    state.teamMap = buildTeamMap(teams);

    const sortedGames = [...games].sort(
      (a, b) => gameSortValue(b) - gameSortValue(a),
    );

    const recentGames =
      sortedGames.slice(0, MAX_VISIBLE_GAMES);

    const hydrated = await mapWithConcurrency(
      recentGames,
      MAX_CONCURRENT_GAMES,
      hydrateGame,
    );

    const usable = hydrated.filter(Boolean);

    els.list.replaceChildren();

    for (const item of usable) {
      els.list.appendChild(renderCard(item));
    }

    renderSummary(games, usable);

    els.empty.classList.toggle(
      "hidden",
      usable.length !== 0,
    );

    const failedCount =
      recentGames.length - usable.length;

    if (failedCount > 0) {
      els.error.textContent =
        `${failedCount} recent game`
        + `${failedCount === 1 ? "" : "s"} `
        + "could not be fully loaded. "
        + "All other recent games remain available.";

      els.error.classList.remove("hidden");
      setStatus("PARTIAL", "error");
    } else {
      showRecentGamesNotice(
        games.length,
        recentGames.length,
      );

      setStatus("READY", "ready");
    }

    if (!els.newGamePanel.classList.contains("hidden")) {
      renderTeamResults("home");
      renderTeamResults("away");
    }
  } catch (error) {
    console.error("M12-C Game Management load failed", error);

    els.error.textContent =
      "Game Management could not load the game list. "
      + "Refresh to try again.";

    els.error.classList.remove("hidden");
    setStatus("ERROR", "error");
  } finally {
    els.refresh.disabled = false;
  }
}

els.refresh.addEventListener("click", () => {
  void loadGames();
});

els.newGameButton.addEventListener("click", () => {
  openNewGamePanel();
});

els.cancelNewGame.addEventListener("click", () => {
  closeNewGamePanel();
});

els.newGameForm.addEventListener("submit", (event) => {
  void createGame(event);
});

els.homeSearch.addEventListener("input", () => {
  renderTeamResults("home");
});

els.awaySearch.addEventListener("input", () => {
  renderTeamResults("away");
});

void loadGames();
