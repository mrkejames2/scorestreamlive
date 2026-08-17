import {
  getClock,
  getGame,
  getLifecycle,
  getRoster,
  getScoringEvents,
  getTeam,
  transitionLifecycle,
  createScoringEvent,
} from "./api.js";

import {
  displaySeconds,
  formatClock,
  soccerAddedTimeMinute,
  updateServerOffset,
} from "./clock.js";

import {
  replaceState,
  setStateAuthoritative,
  state,
} from "./state.js";
import { connectControlSocket } from "./socket.js";

const byId = (id) => document.getElementById(id);

const LIFECYCLE_ACTION_BY_PHASE = {
  pregame: "start_first_half",
  first_half: "end_first_half",
  halftime: "start_second_half",
  second_half: "end_game",
  full_time: null,
};

const ACTION_LABELS = {
  start_first_half: "Start First Half",
  end_first_half: "End First Half",
  start_second_half: "Start Second Half",
  end_game: "End Game",
};

let commandInFlight = false;
let scoringCommandInFlight = false;
let operatorMessageTimer = null;
let connectionController = null;

function gameIdFromPage() {
  return document.body.dataset.gameId;
}

function text(id, value) {
  const node = byId(id);
  if (node) node.textContent = value ?? "—";
}

function phaseLabel(value) {
  return value ? String(value).replaceAll("_", " ").toUpperCase() : "UNKNOWN";
}

function playerDisplayName(player) {
  const parts = [player.first_name, player.last_name].filter(Boolean);
  return parts.length ? parts.join(" ") : "Unknown Player";
}

function showOperatorMessage(message, mode = "info", timeoutMs = 5000) {
  const node = byId("operator-message");

  if (operatorMessageTimer) {
    window.clearTimeout(operatorMessageTimer);
    operatorMessageTimer = null;
  }

  node.textContent = message;
  node.classList.remove(
    "hidden",
    "operator-info",
    "operator-success",
    "operator-warning",
    "operator-error",
  );
  node.classList.add(`operator-${mode}`);

  if (timeoutMs > 0) {
    operatorMessageTimer = window.setTimeout(() => {
      node.classList.add("hidden");
    }, timeoutMs);
  }
}

function renderRoster(containerId, players) {
  const container = byId(containerId);
  container.replaceChildren();

  if (!players.length) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.textContent = "No players.";
    container.appendChild(empty);
    return;
  }

  for (const player of players) {
    const row = document.createElement("div");
    row.className = "roster-player";

    const jersey = document.createElement("div");
    jersey.className = "jersey";
    jersey.textContent = player.jersey_number == null ? "—" : `#${player.jersey_number}`;

    const name = document.createElement("div");
    name.className = "player-name";
    name.textContent = playerDisplayName(player);

    row.append(jersey, name);
    container.appendChild(row);
  }
}


function populateScorerSelect(selectId, players) {
  const select = byId(selectId);
  if (!select) return;

  const previous = select.value;
  select.replaceChildren();

  const teamGoal = document.createElement("option");
  teamGoal.value = "";
  teamGoal.textContent = "Team Goal / Unknown Scorer";
  select.appendChild(teamGoal);

  for (const player of players) {
    const option = document.createElement("option");
    option.value = player.id;
    const jersey = player.jersey_number == null ? "" : `#${player.jersey_number} `;
    option.textContent = `${jersey}${playerDisplayName(player)}`;
    select.appendChild(option);
  }

  if ([...select.options].some((option) => option.value === previous)) {
    select.value = previous;
  }
}

function scoringIsAllowed() {
  return ["first_half", "second_half"].includes(state.lifecycle?.phase);
}

function mutationStateIsReady() {
  return (
    state.socketConnected
    && state.stateAuthoritative
    && state.connectionState === "live"
  );
}

function renderScoringControls() {
  const ready = mutationStateIsReady();
  const goalEnabled =
    ready
    && scoringIsAllowed()
    && !scoringCommandInFlight;

  for (const id of ["home-goal-button", "away-goal-button"]) {
    const button = byId(id);
    if (button) button.disabled = !goalEnabled;
  }

  for (const id of ["home-scorer-select", "away-scorer-select"]) {
    const select = byId(id);
    if (select) {
      select.disabled =
        !ready
        || !scoringIsAllowed()
        || scoringCommandInFlight;
    }
  }
}

function scorerName(event) {
  if (!event.player_id) return "Team goal / scorer not recorded";

  const player = [...state.homeRoster, ...state.awayRoster].find(
    (candidate) => candidate.id === event.player_id,
  );

  return player ? playerDisplayName(player) : `Player ${event.player_id}`;
}

function scoringTeamName(event) {
  if (state.homeTeam && event.team_id === state.homeTeam.id) return state.homeTeam.name;
  if (state.awayTeam && event.team_id === state.awayTeam.id) return state.awayTeam.name;
  return "Unknown Team";
}

function formatEventTime(event) {
  const elapsed = Number(event.game_elapsed_seconds);

  if (!Number.isFinite(elapsed) || elapsed < 0) {
    // Legacy scoring events created before M10-E cleanup do not have a
    // durable game-time snapshot. Do not misrepresent wall-clock time as
    // match time.
    return "—";
  }

  // Soccer notation uses the minute in which play is occurring:
  // 00:01 -> 1', 31:07 -> 32', 45:00 -> 45'.
  if (elapsed <= 0) return "1'";

  const wholeSeconds = Math.floor(elapsed);
  const minute = Math.floor((wholeSeconds - 1) / 60) + 1;
  return `${minute}'`;
}

function renderScoring() {
  const container = byId("scoring-list");
  container.replaceChildren();

  if (!state.scoringEvents.length) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.textContent = "No scoring events.";
    container.appendChild(empty);
    return;
  }

  for (const event of [...state.scoringEvents].reverse()) {
    const row = document.createElement("div");
    row.className = "scoring-event";

    const time = document.createElement("div");
    time.className = "scoring-time";
    time.textContent = formatEventTime(event);

    const detail = document.createElement("div");
    const team = document.createElement("div");
    team.className = "scoring-team";
    team.textContent = scoringTeamName(event);

    const player = document.createElement("div");
    player.className = "scoring-player";
    player.textContent = scorerName(event);

    detail.append(team, player);
    row.append(time, detail);
    container.appendChild(row);
  }
}

function renderLifecycleControls() {
  const validAction =
    LIFECYCLE_ACTION_BY_PHASE[state.lifecycle?.phase] ?? null;
  const ready = mutationStateIsReady();
  const buttons = document.querySelectorAll(".lifecycle-button");

  for (const button of buttons) {
    const isValidAction = button.dataset.action === validAction;

    // M10-G presentation hint: on narrow phones we show only the lifecycle
    // action relevant to the current authoritative phase. This class does
    // not grant mutation permission; M10-F readiness still controls disabled.
    button.classList.toggle("current-action", isValidAction);

    button.disabled =
      commandInFlight
      || !ready
      || !isValidAction;
    button.classList.toggle("valid-action", isValidAction && ready);
  }

  let status = "READY";

  if (commandInFlight) {
    status = "UPDATING...";
  } else if (state.connectionState === "recovering") {
    status = "RECOVERING STATE...";
  } else if (state.connectionState === "reconnecting") {
    status = "RECONNECTING...";
  } else if (!ready) {
    status = "CONTROLS PAUSED";
  }

  text("command-status", status);
}


function syncMatchDayUx() {
  const phase = state.lifecycle?.phase || "pregame";

  text(
    "ux-phase-chip",
    String(phase).replaceAll("_", " ").toUpperCase(),
  );

  const connectionLabel = {
    live: "LIVE",
    recovering: "RECOVERING",
    reconnecting: "RECONNECTING",
    offline: "OFFLINE",
    connecting: "CONNECTING",
  }[state.connectionState] || "CONNECTING";

  text("ux-connection-chip", connectionLabel);

  let operatorState = "READY";
  if (commandInFlight || scoringCommandInFlight) {
    operatorState = "UPDATING";
  } else if (!mutationStateIsReady()) {
    operatorState = "PAUSED";
  }

  text("ux-operator-chip", operatorState);
  document.body.dataset.phase = phase;
  document.body.dataset.connectionState = state.connectionState;
}

let goalFeedbackTimer = null;

function showGoalFeedback(detail) {
  const panel = byId("goal-feedback");
  if (!panel) return;
  if (goalFeedbackTimer) window.clearTimeout(goalFeedbackTimer);
  text("goal-feedback-detail", detail || "Score updated");
  panel.classList.remove("hidden");
  goalFeedbackTimer = window.setTimeout(() => panel.classList.add("hidden"), 1800);
}

function renderLiveMetadata() {
  const detail = {
    live: "LIVE — authoritative state confirmed",
    recovering: "RECOVERING — verifying authoritative state",
    reconnecting: "RECONNECTING — controls paused",
    offline: "OFFLINE — controls paused",
    connecting: "CONNECTING — controls paused",
  }[state.connectionState] || "CONNECTING";

  text("connection-detail", detail);

  if (!state.lastLiveEvent) {
    text("last-live-event", "—");
    return;
  }

  const eventTime =
    state.lastLiveEvent.at instanceof Date
      ? state.lastLiveEvent.at.toLocaleTimeString()
      : "—";

  text(
    "last-live-event",
    `${state.lastLiveEvent.name} @ ${eventTime}`,
  );
}

function renderStaticState() {
  text("home-team-name", state.homeTeam?.name);
  text("away-team-name", state.awayTeam?.name);
  text("home-roster-team-name", state.homeTeam?.name || "Home");
  text("away-roster-team-name", state.awayTeam?.name || "Away");
  text("home-score", state.game?.home_score ?? 0);
  text("away-score", state.game?.away_score ?? 0);
  text("phase-display", phaseLabel(state.lifecycle?.phase));
  text("lifecycle-phase", state.lifecycle?.phase);
  text("lifecycle-version", state.lifecycle?.version);
  text("clock-status", state.clock?.status);
  text("clock-mode", state.clock?.mode);
  text("clock-version", state.clock?.version);
  text("clock-duration", state.clock ? `${state.clock.duration_seconds} sec` : "—");

  renderRoster("home-roster", state.homeRoster);
  renderRoster("away-roster", state.awayRoster);
  text("home-scoring-team-name", state.homeTeam?.name || "Home");
  text("away-scoring-team-name", state.awayTeam?.name || "Away");
  populateScorerSelect("home-scorer-select", state.homeRoster);
  populateScorerSelect("away-scorer-select", state.awayRoster);
  renderScoring();
  renderLiveMetadata();
  renderLifecycleControls();
  renderScoringControls();
}

function renderClock() {
  if (!state.clock) {
    text("clock-display", "00:00");
    text("added-time", "");
    return;
  }

  text("clock-display", formatClock(displaySeconds(state.clock)));
  const added = soccerAddedTimeMinute(state.clock);
  text("added-time", added === null ? "" : `+${added}`);
}

function setConnectionUi(mode, detail = null) {
  const badge = byId("connection-badge");
  const label = byId("connection-label");
  const message = byId("socket-message");
  const messageText = byId("socket-message-text");

  badge.classList.remove(
    "connection-live",
    "connection-connecting",
    "connection-recovering",
    "connection-offline",
  );

  if (mode === "live") {
    badge.classList.add("connection-live");
    label.textContent = "LIVE";
    message.classList.add("hidden");
  } else if (mode === "recovering") {
    badge.classList.add("connection-recovering");
    label.textContent = "RECOVERING";
    message.classList.remove("hidden");
    if (messageText) {
      messageText.textContent =
        detail
        || "Connection restored. ScoreStreamLive is verifying authoritative game state before controls are re-enabled.";
    }
  } else if (mode === "reconnecting") {
    badge.classList.add("connection-connecting");
    label.textContent = "RECONNECTING";
    message.classList.remove("hidden");
    if (messageText) {
      messageText.textContent =
        detail
        || "Live connection was interrupted. Controls are paused while ScoreStreamLive reconnects.";
    }
  } else {
    badge.classList.add("connection-offline");
    label.textContent = "OFFLINE";
    message.classList.remove("hidden");
    if (messageText) {
      messageText.textContent =
        detail
        || "ScoreStreamLive is offline. Controls are paused to prevent changes from stale state.";
    }
  }

  renderLiveMetadata();
  renderLifecycleControls();
  renderScoringControls();
  syncMatchDayUx();
}

function setLoading(isLoading) {
  byId("loading-state").classList.toggle("hidden", !isLoading);
  if (isLoading) byId("control-content").classList.add("hidden");
}

function showError(error) {
  byId("error-state").classList.remove("hidden");
  text("error-message", error?.message || String(error));
}

function clearError() {
  byId("error-state").classList.add("hidden");
}

async function fetchAuthoritativeState({ showLoading = false } = {}) {
  const gameId = gameIdFromPage();
  state.gameId = gameId;
  clearError();
  if (showLoading) setLoading(true);

  try {
    const game = await getGame(gameId);
    const [homeTeam, awayTeam, homeRoster, awayRoster, lifecycle, clock, scoringEvents] =
      await Promise.all([
        getTeam(game.home_team_id),
        getTeam(game.away_team_id),
        getRoster(game.home_team_id),
        getRoster(game.away_team_id),
        getLifecycle(gameId),
        getClock(gameId),
        getScoringEvents(gameId),
      ]);

    replaceState({
      game,
      homeTeam,
      awayTeam,
      homeRoster,
      awayRoster,
      lifecycle,
      clock,
      scoringEvents,
    });

    updateServerOffset(clock);
    renderStaticState();
    renderClock();
    byId("control-content").classList.remove("hidden");
  } catch (error) {
    console.error("M10-F authoritative state load failed", error);
    showError(error);
    throw error;
  } finally {
    if (showLoading) setLoading(false);
  }
}

async function runLifecycleAction(action) {
  if (commandInFlight) return;

  const expectedAction = LIFECYCLE_ACTION_BY_PHASE[state.lifecycle?.phase] ?? null;
  if (action !== expectedAction) {
    showOperatorMessage(
      "That lifecycle action is no longer valid. Refreshing authoritative state.",
      "warning",
    );
    await fetchAuthoritativeState();
    return;
  }

  if (!state.lifecycle?.version || !state.clock?.version) {
    showOperatorMessage(
      "Lifecycle or clock version is unavailable. Refreshing authoritative state.",
      "warning",
    );
    await fetchAuthoritativeState();
    return;
  }

  commandInFlight = true;
  renderLifecycleControls();
  const label = ACTION_LABELS[action] || action;

  try {
    const response = await transitionLifecycle(gameIdFromPage(), {
      action,
      expectedLifecycleVersion: state.lifecycle.version,
      expectedClockVersion: state.clock.version,
    });

    if (response?.lifecycle) state.lifecycle = response.lifecycle;
    if (response?.clock) {
      state.clock = response.clock;
      updateServerOffset(state.clock);
    }

    renderStaticState();
    renderClock();
    showOperatorMessage(`${label} completed.`, "success", 3000);
  } catch (error) {
    if (error?.status === 409) {
      setStateAuthoritative(false);
      renderLifecycleControls();
      renderScoringControls();
      syncMatchDayUx();

      showOperatorMessage(
        "Another controller changed the game first. Your command was not retried. ScoreStreamLive is refreshing the latest game state.",
        "warning",
        7000,
      );
      try {
        await fetchAuthoritativeState();
      } catch (_) {}
    } else if (error?.status === 422 || error?.status === 400) {
      showOperatorMessage(`Lifecycle command rejected: ${error.message}`, "error", 7000);
      try {
        await fetchAuthoritativeState();
      } catch (_) {}
    } else {
      showOperatorMessage(`Lifecycle command failed: ${error?.message || error}`, "error", 7000);
    }
  } finally {
    commandInFlight = false;
    renderLifecycleControls();
  }
}


async function runScoringAction(side) {
  if (scoringCommandInFlight) return;

  if (!mutationStateIsReady()) {
    showOperatorMessage(
      "Controls are paused until the live connection and authoritative game state are confirmed.",
      "warning",
      6000,
    );
    return;
  }

  if (!scoringIsAllowed()) {
    showOperatorMessage("Goals can only be recorded during the first or second half.", "warning", 6000);
    return;
  }

  const team = side === "home" ? state.homeTeam : state.awayTeam;
  const select = byId(side === "home" ? "home-scorer-select" : "away-scorer-select");
  if (!team) {
    showOperatorMessage("Team state is unavailable. Refreshing authoritative state.", "warning", 6000);
    await fetchAuthoritativeState();
    return;
  }

  const playerId = select?.value || null;
  scoringCommandInFlight = true;
  renderScoringControls();

  try {
    await createScoringEvent(gameIdFromPage(), team.id, playerId);
    showOperatorMessage(`${team.name} goal recorded.`, "success", 3000);
  } catch (error) {
    showOperatorMessage(`Goal was not recorded: ${error?.message || error}`, "error", 7000);
    try {
      await fetchAuthoritativeState();
    } catch (_) {}
  } finally {
    scoringCommandInFlight = false;
    renderScoringControls();
  }
}

function applyScoreUpdate(payload) {
  if (!state.game) return;
  state.game = {
    ...state.game,
    home_score: payload.home_score,
    away_score: payload.away_score,
  };
  renderStaticState();
}

function applyScoringEvent(payload) {
  if (!state.scoringEvents.some((event) => event.id === payload.id)) {
    state.scoringEvents = [...state.scoringEvents, payload];
  }
  renderScoring();
  renderLiveMetadata();
  showGoalFeedback("Goal committed");
  syncMatchDayUx();
}

function applyPhaseUpdate(payload) {
  state.lifecycle = { ...(state.lifecycle || {}), ...payload };
  renderStaticState();
}

function applyClockUpdate(payload) {
  state.clock = { ...(state.clock || {}), ...payload };
  updateServerOffset(state.clock);
  renderStaticState();
  renderClock();
}

async function manualAuthoritativeRefresh() {
  if (
    connectionController?.socket?.connected
    && !mutationStateIsReady()
  ) {
    await connectionController.recoverAuthoritativeState();
    return;
  }

  await fetchAuthoritativeState({ showLoading: true });
  renderLifecycleControls();
  renderScoringControls();
  syncMatchDayUx();
}

byId("refresh-button")?.addEventListener(
  "click",
  () => manualAuthoritativeRefresh(),
);
byId("retry-button")?.addEventListener(
  "click",
  () => manualAuthoritativeRefresh(),
);

for (const button of document.querySelectorAll(".lifecycle-button")) {
  button.addEventListener("click", () => runLifecycleAction(button.dataset.action));
}

byId("home-goal-button")?.addEventListener("click", () => runScoringAction("home"));
byId("away-goal-button")?.addEventListener("click", () => runScoringAction("away"));

// Local presentation only. No per-second REST polling and no clock:tick.
setInterval(renderClock, 250);

await fetchAuthoritativeState({ showLoading: true });

try {
  connectionController = connectControlSocket({
    gameId: gameIdFromPage(),

    onTransportConnected: () => {
      setConnectionUi("recovering");
    },

    onRecoveryStarted: () => {
      setConnectionUi("recovering");
    },

    onReady: () => {
      setConnectionUi("live");
      showOperatorMessage(
        "Live connection restored. Authoritative game state confirmed.",
        "success",
        3500,
      );
    },

    onDisconnected: () => {
      setConnectionUi("offline");
    },

    onReconnectAttempt: () => {
      setConnectionUi("reconnecting");
    },

    onRecoveryFailed: (error) => {
      setConnectionUi(
        "recovering",
        "Connection is back, but the latest authoritative game state could not be verified. Controls remain paused. Tap Refresh to try again.",
      );
      showOperatorMessage(
        `State recovery failed: ${error?.message || error}`,
        "error",
        7000,
      );
    },

    onScoreUpdated: (payload) => {
      applyScoreUpdate(payload);
      renderLiveMetadata();
    },

    onScoringEventCreated: (payload) => {
      applyScoringEvent(payload);
    },

    onPhaseUpdated: (payload) => {
      applyPhaseUpdate(payload);
      renderLiveMetadata();
    },

    onClockUpdated: (payload) => {
      applyClockUpdate(payload);
      renderLiveMetadata();
    },

    onAuthoritativeRefresh: async () => {
      await fetchAuthoritativeState({ showLoading: false });
    },
  });
} catch (error) {
  console.error("M10-F live connection failed", error);
  setStateAuthoritative(false);
  setConnectionUi("offline");
}


// M10-F initial connection/UX synchronization
syncMatchDayUx();
