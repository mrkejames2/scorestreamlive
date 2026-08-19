const byId = (id) => document.getElementById(id);

const gameId = document.body.dataset.gameId;

const state = {
  game: null,
  homeTeam: null,
  awayTeam: null,
  homeRoster: [],
  awayRoster: [],
  creatingSide: null,
};

function setStatus(label, status) {
  const node = byId("setup-status");
  node.textContent = label;
  node.dataset.state = status;
}

async function api(path, options = {}) {
  const {
    method = "GET",
    payload = null,
  } = options;

  const headers = { "Accept": "application/json" };
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

  if (!response.ok) {
    let detail = "";

    try {
      const data = await response.json();
      detail =
        typeof data?.detail === "string"
          ? data.detail
          : JSON.stringify(data?.detail || "");
    } catch (_) {
      // Keep generic HTTP fallback.
    }

    throw new Error(
      detail
        ? `${path} returned HTTP ${response.status}: ${detail}`
        : `${path} returned HTTP ${response.status}`,
    );
  }

  return response.json();
}

function normalizedColor(value, fallback) {
  const raw = String(value || "").trim();
  return /^#[0-9A-Fa-f]{6}$/.test(raw)
    ? raw.toUpperCase()
    : fallback;
}

function teamInitials(team, fallback) {
  const source = String(team?.short_name || team?.name || fallback).trim();
  if (!source) return fallback.slice(0, 1);

  const words = source.split(/\s+/).filter(Boolean);
  if (words.length >= 2) {
    return `${words[0][0]}${words[1][0]}`.toUpperCase();
  }

  return source.slice(0, 3).toUpperCase();
}

function renderTeamBrand(side, team) {
  const summary = byId(`${side}-summary`);
  const brand = byId(`${side}-brand`);
  const logo = byId(`${side}-brand-logo`);
  const fallback = byId(`${side}-brand-fallback`);

  const primary = normalizedColor(team?.primary_color, "#2A77FF");
  const secondary = normalizedColor(team?.secondary_color, "#FFFFFF");

  summary.style.setProperty("--team-primary", primary);
  summary.style.setProperty("--team-secondary", secondary);
  brand.style.setProperty("--team-primary", primary);
  brand.style.setProperty("--team-secondary", secondary);

  fallback.textContent = teamInitials(
    team,
    side === "home" ? "HOME" : "AWAY",
  );

  const logoUrl = String(team?.logo_url || "").trim();

  if (!logoUrl) {
    logo.removeAttribute("src");
    logo.alt = "";
    logo.classList.add("hidden");
    fallback.classList.remove("hidden");
    return;
  }

  logo.src = logoUrl;
  logo.alt = `${team?.name || "Team"} logo`;
  logo.classList.remove("hidden");
  fallback.classList.add("hidden");

  logo.onerror = () => {
    logo.classList.add("hidden");
    fallback.classList.remove("hidden");
  };
}

function teamDisplayName(team, fallback) {
  return team?.name || team?.short_name || fallback;
}

function rosterFor(side) {
  return side === "home"
    ? state.homeRoster
    : state.awayRoster;
}

function setRoster(side, roster) {
  if (side === "home") {
    state.homeRoster = roster;
  } else {
    state.awayRoster = roster;
  }
}

function renderRoster(side) {
  const roster = rosterFor(side);
  const list = byId(`${side}-roster-list`);
  const empty = byId(`${side}-roster-empty`);
  const count = roster.length;

  list.replaceChildren();

  for (const player of roster) {
    const fragment = byId("player-row-template").content.cloneNode(true);

    fragment.querySelector(".jersey-number").textContent =
      player.jersey_number === null || player.jersey_number === undefined
        ? "—"
        : String(player.jersey_number);

    fragment.querySelector(".player-name").textContent =
      `${player.first_name} ${player.last_name}`;

    list.appendChild(fragment);
  }

  empty.classList.toggle("hidden", count !== 0);

  byId(`${side}-card-count`).textContent = String(count);
  byId(`${side}-roster-count`).textContent =
    `${count} player${count === 1 ? "" : "s"}`;
}

async function refreshRoster(side) {
  const team = side === "home"
    ? state.homeTeam
    : state.awayTeam;

  const roster = await api(`/api/teams/${team.id}/players`);
  setRoster(side, roster);
  renderRoster(side);
}

function parsePlayerForm(side) {
  const firstName = byId(`${side}-player-first-name`).value.trim();
  const lastName = byId(`${side}-player-last-name`).value.trim();
  const jerseyRaw = byId(`${side}-player-jersey`).value.trim();

  if (!firstName || !lastName) {
    throw new Error("First name and last name are required.");
  }

  let jerseyNumber = null;

  if (jerseyRaw !== "") {
    jerseyNumber = Number(jerseyRaw);

    if (
      !Number.isInteger(jerseyNumber)
      || jerseyNumber < 0
      || jerseyNumber > 999
    ) {
      throw new Error("Jersey number must be a whole number from 0 to 999.");
    }
  }

  return {
    first_name: firstName,
    last_name: lastName,
    jersey_number: jerseyNumber,
  };
}

function setFormBusy(side, busy) {
  const form = byId(`${side}-player-form`);
  const button = byId(`${side}-add-player`);

  for (const field of form.querySelectorAll("input")) {
    field.disabled = busy;
  }

  button.disabled = busy;
  button.textContent = busy
    ? "Adding Player..."
    : `+ Add ${side === "home" ? "Home" : "Away"} Player`;
}

function showFormError(side, message) {
  const node = byId(`${side}-player-error`);
  node.textContent = message;
  node.classList.toggle("hidden", !message);
}

function resetPlayerForm(side) {
  byId(`${side}-player-form`).reset();
  byId(`${side}-player-first-name`).focus();
}

async function createPlayer(side) {
  if (state.creatingSide !== null) return;

  const team = side === "home"
    ? state.homeTeam
    : state.awayTeam;

  showFormError(side, "");

  let values;

  try {
    values = parsePlayerForm(side);
  } catch (error) {
    showFormError(side, error.message);
    return;
  }

  state.creatingSide = side;
  setFormBusy(side, true);

  try {
    await api("/api/players", {
      method: "POST",
      payload: {
        team_id: team.id,
        ...values,
      },
    });

    await refreshRoster(side);
    resetPlayerForm(side);
  } catch (error) {
    console.error("M12-E player creation failed", error);
    showFormError(side, error.message);
  } finally {
    state.creatingSide = null;
    setFormBusy(side, false);
  }
}

async function bootstrap() {
  setStatus("LOADING", "loading");

  try {
    const game = await api(`/api/games/${gameId}`);

    const [homeTeam, awayTeam, homeRoster, awayRoster] =
      await Promise.all([
        api(`/api/teams/${game.home_team_id}`),
        api(`/api/teams/${game.away_team_id}`),
        api(`/api/teams/${game.home_team_id}/players`),
        api(`/api/teams/${game.away_team_id}/players`),
      ]);

    state.game = game;
    state.homeTeam = homeTeam;
    state.awayTeam = awayTeam;
    state.homeRoster = homeRoster;
    state.awayRoster = awayRoster;

    byId("game-name").textContent = game.name || "Game Setup";

    byId("home-team-name").textContent =
      teamDisplayName(homeTeam, "Home");
    byId("away-team-name").textContent =
      teamDisplayName(awayTeam, "Away");

    byId("home-roster-title").textContent =
      teamDisplayName(homeTeam, "Home");
    byId("away-roster-title").textContent =
      teamDisplayName(awayTeam, "Away");

    renderTeamBrand("home", homeTeam);
    renderTeamBrand("away", awayTeam);

    renderRoster("home");
    renderRoster("away");

    byId("game-summary").classList.remove("hidden");
    byId("roster-grid").classList.remove("hidden");

    setStatus("READY", "ready");
  } catch (error) {
    console.error("M12-E roster setup load failed", error);

    byId("setup-error").textContent =
      "Game Setup could not load authoritative Game/Team/Roster state. "
      + error.message;

    byId("setup-error").classList.remove("hidden");
    setStatus("ERROR", "error");
  }
}

byId("home-player-form").addEventListener("submit", (event) => {
  event.preventDefault();
  void createPlayer("home");
});

byId("away-player-form").addEventListener("submit", (event) => {
  event.preventDefault();
  void createPlayer("away");
});

void bootstrap();
