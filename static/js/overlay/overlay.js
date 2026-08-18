const byId = (id) => document.getElementById(id);

const gameId = document.body.dataset.gameId;

const CLOCK_RESYNC_MS = 5000;
const GOAL_BANNER_VISIBLE_MS = 5000;
const MATCH_STATE_BANNER_VISIBLE_MS = 5000;

const state = {
  game: null,
  homeTeam: null,
  awayTeam: null,
  lifecycle: null,
  clock: null,
  homeRoster: [],
  awayRoster: [],

  clockAnchorElapsed: 0,
  clockAnchorPerformanceMs: null,

  socketConnected: false,
  recovering: false,
  clockResyncing: false,
  hasAuthoritativeState: false,

  goalBannerTimeout: null,
  lastGoalEventId: null,

  matchStateBannerTimeout: null,
  lastPresentedPhase: null,
};

function api(path) {
  return fetch(path, {
    method: "GET",
    headers: { "Accept": "application/json" },
    cache: "no-store",
  }).then(async (response) => {
    if (!response.ok) {
      throw new Error(`${path} returned HTTP ${response.status}`);
    }
    return response.json();
  });
}

function phaseLabel(value) {
  const phase = String(value || "pregame");
  const labels = {
    pregame: "PREGAME",
    first_half: "1ST HALF",
    halftime: "HALFTIME",
    second_half: "2ND HALF",
    full_time: "FULL TIME",
  };
  return labels[phase] || phase.replaceAll("_", " ").toUpperCase();
}

function clampElapsed(value) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.max(0, Math.floor(n)) : 0;
}

function authoritativeElapsed(clock) {
  if (!clock) return 0;
  const direct = Number(clock.authoritative_elapsed_seconds);
  if (Number.isFinite(direct)) return Math.max(0, direct);
  return clampElapsed(clock.elapsed_seconds);
}

function captureClockAnchor(clock) {
  state.clockAnchorElapsed = authoritativeElapsed(clock);
  state.clockAnchorPerformanceMs = performance.now();
}

function renderedElapsed() {
  if (!state.clock) return 0;

  let elapsed = state.clockAnchorElapsed;

  if (
    state.clock.status === "running"
    && state.clockAnchorPerformanceMs !== null
  ) {
    elapsed += Math.max(
      0,
      Math.floor((performance.now() - state.clockAnchorPerformanceMs) / 1000),
    );
  }

  return elapsed;
}

function clockSecondsForDisplay() {
  const elapsed = renderedElapsed();

  if (state.clock?.mode === "count_down") {
    const duration = Number(state.clock.duration_seconds || 0);
    return Math.max(0, duration - elapsed);
  }

  return elapsed;
}

function formatClock(totalSeconds) {
  const seconds = Math.max(0, Math.floor(totalSeconds));
  const minutes = Math.floor(seconds / 60);
  const remainder = seconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(remainder).padStart(2, "0")}`;
}

function setPresentationConnectionState() {
  const overlay = byId("overlay-scoreboard");
  const badge = byId("overlay-status-badge");

  if (!overlay || !badge) return;

  if (state.socketConnected) {
    overlay.classList.remove("overlay-recovering");
    badge.textContent = "LIVE";
    badge.dataset.state = "live";
  } else if (state.hasAuthoritativeState) {
    overlay.classList.add("overlay-recovering");
    badge.textContent = "RECONNECTING";
    badge.dataset.state = "recovering";
  } else {
    badge.textContent = "CONNECTING";
    badge.dataset.state = "connecting";
  }
}

function render() {
  if (!state.game) return;

  byId("home-team-name").textContent =
    state.homeTeam?.short_name || state.homeTeam?.name || "HOME";

  byId("away-team-name").textContent =
    state.awayTeam?.short_name || state.awayTeam?.name || "AWAY";

  byId("home-score").textContent = String(state.game.home_score ?? 0);
  byId("away-score").textContent = String(state.game.away_score ?? 0);
  byId("phase-display").textContent = phaseLabel(state.lifecycle?.phase);
  byId("clock-display").textContent = formatClock(clockSecondsForDisplay());

  setPresentationConnectionState();
}

function eventGameId(payload) {
  return String(payload?.game_id || payload?.id || "");
}

function belongsToThisGame(payload) {
  return eventGameId(payload) === String(gameId);
}

function playerDisplayName(playerId) {
  if (!playerId) return "";

  const player = [...state.homeRoster, ...state.awayRoster]
    .find((candidate) => String(candidate.id) === String(playerId));

  if (!player) return "";

  return [player.first_name, player.last_name]
    .filter(Boolean)
    .join(" ")
    .trim();
}

function teamForId(teamId) {
  if (String(state.homeTeam?.id) === String(teamId)) return state.homeTeam;
  if (String(state.awayTeam?.id) === String(teamId)) return state.awayTeam;
  return null;
}

function scoringMinute(payload) {
  const raw = Number(payload?.game_elapsed_seconds);

  if (!Number.isFinite(raw) || raw < 0) return "";

  return `${Math.floor(raw / 60) + 1}'`;
}

function hideGoalBanner() {
  const banner = byId("goal-banner");
  if (!banner || banner.classList.contains("hidden")) return;

  banner.classList.remove("goal-banner-enter");
  banner.classList.add("goal-banner-exit");

  window.setTimeout(() => {
    banner.classList.add("hidden");
    banner.classList.remove("goal-banner-exit");
  }, 240);
}

function showGoalBanner(payload) {
  if (!payload || payload.event_type !== "goal") return;

  const eventId = String(payload.id || "");
  if (eventId && eventId === state.lastGoalEventId) return;

  state.lastGoalEventId = eventId || null;

  const team = teamForId(payload.team_id);
  const scorerName = playerDisplayName(payload.player_id);
  const minute = scoringMinute(payload);

  byId("goal-team-name").textContent =
    team?.short_name || team?.name || "GOAL";

  byId("goal-scorer-name").textContent =
    scorerName || "TEAM GOAL";

  byId("goal-minute").textContent = minute;

  const banner = byId("goal-banner");

  if (state.goalBannerTimeout !== null) {
    window.clearTimeout(state.goalBannerTimeout);
  }

  banner.classList.remove("hidden", "goal-banner-exit", "goal-banner-enter");
  void banner.offsetWidth;
  banner.classList.add("goal-banner-enter");

  state.goalBannerTimeout = window.setTimeout(() => {
    hideGoalBanner();
    state.goalBannerTimeout = null;
  }, GOAL_BANNER_VISIBLE_MS);
}

function matchStateTitle(phase) {
  const titles = {
    first_half: "FIRST HALF",
    halftime: "HALFTIME",
    second_half: "SECOND HALF",
    full_time: "FULL TIME",
  };

  return titles[phase] || "";
}

function matchStateScoreline() {
  const home =
    state.homeTeam?.short_name || state.homeTeam?.name || "HOME";
  const away =
    state.awayTeam?.short_name || state.awayTeam?.name || "AWAY";

  const homeScore = state.game?.home_score ?? 0;
  const awayScore = state.game?.away_score ?? 0;

  return `${home} ${homeScore} — ${awayScore} ${away}`;
}

function hideMatchStateBanner() {
  const banner = byId("match-state-banner");
  if (!banner || banner.classList.contains("hidden")) return;

  banner.classList.remove("match-state-enter");
  banner.classList.add("match-state-exit");

  window.setTimeout(() => {
    banner.classList.add("hidden");
    banner.classList.remove("match-state-exit");
  }, 240);
}

function showMatchStateBanner(phase) {
  if (!phase || phase === "pregame") return;
  if (phase === state.lastPresentedPhase) return;

  const title = matchStateTitle(phase);
  if (!title) return;

  state.lastPresentedPhase = phase;

  byId("match-state-title").textContent = title;
  byId("match-state-scoreline").textContent = matchStateScoreline();

  const banner = byId("match-state-banner");

  if (state.matchStateBannerTimeout !== null) {
    window.clearTimeout(state.matchStateBannerTimeout);
  }

  banner.classList.remove(
    "hidden",
    "match-state-exit",
    "match-state-enter",
  );

  void banner.offsetWidth;
  banner.classList.add("match-state-enter");

  state.matchStateBannerTimeout = window.setTimeout(() => {
    hideMatchStateBanner();
    state.matchStateBannerTimeout = null;
  }, MATCH_STATE_BANNER_VISIBLE_MS);
}

async function loadAuthoritativeState() {
  const game = await api(`/api/games/${gameId}`);

  const [
    homeTeam,
    awayTeam,
    lifecycle,
    clock,
    homeRoster,
    awayRoster,
  ] = await Promise.all([
    api(`/api/teams/${game.home_team_id}`),
    api(`/api/teams/${game.away_team_id}`),
    api(`/api/games/${gameId}/lifecycle`),
    api(`/api/games/${gameId}/clock`),
    api(`/api/teams/${game.home_team_id}/players`),
    api(`/api/teams/${game.away_team_id}/players`),
  ]);

  state.game = game;
  state.homeTeam = homeTeam;
  state.awayTeam = awayTeam;
  state.lifecycle = lifecycle;
  state.clock = clock;
  state.homeRoster = homeRoster;
  state.awayRoster = awayRoster;
  state.hasAuthoritativeState = true;

  captureClockAnchor(clock);
  render();

  byId("overlay-scoreboard").classList.remove("overlay-loading");
  byId("overlay-error").classList.add("hidden");
}

async function resyncAuthoritativeClock() {
  if (state.clockResyncing) return;

  state.clockResyncing = true;

  try {
    const clock = await api(`/api/games/${gameId}/clock`);
    state.clock = clock;
    captureClockAnchor(clock);
    render();
  } catch (error) {
    console.error("M11-F clock-only authoritative resync failed", error);
  } finally {
    state.clockResyncing = false;
  }
}

async function recoverAuthoritativeState() {
  if (state.recovering) return;

  state.recovering = true;
  setPresentationConnectionState();

  try {
    await loadAuthoritativeState();
  } catch (error) {
    console.error("M11-F authoritative recovery failed", error);

    if (!state.hasAuthoritativeState) {
      byId("overlay-error").classList.remove("hidden");
    }
  } finally {
    state.recovering = false;
    setPresentationConnectionState();
  }
}

function lifecyclePhaseFromPayload(payload) {
  return String(payload?.phase || "");
}

function applyLifecyclePresentation(payload) {
  if (!belongsToThisGame(payload)) return;

  const phase = lifecyclePhaseFromPayload(payload);
  if (!phase) return;

  state.lifecycle = {
    ...(state.lifecycle || {}),
    ...payload,
  };

  render();
  showMatchStateBanner(phase);
  void recoverAuthoritativeState();
}

function installSocketHandlers(socket) {
  socket.on("connect", async () => {
    state.socketConnected = true;
    setPresentationConnectionState();
    await recoverAuthoritativeState();

    // Recovery is not a new match transition. Seed the current phase so
    // reconnects and page refreshes do not replay stale match-state banners.
    state.lastPresentedPhase = state.lifecycle?.phase || null;
  });

  socket.on("disconnect", () => {
    state.socketConnected = false;
    setPresentationConnectionState();
  });

  socket.io.on("reconnect_attempt", () => {
    state.socketConnected = false;
    setPresentationConnectionState();
  });

  const recoverIfThisGame = (payload) => {
    if (belongsToThisGame(payload)) {
      void recoverAuthoritativeState();
    }
  };

  socket.on("game:score_updated", recoverIfThisGame);

  socket.on("scoring_event:created", (payload) => {
    if (!belongsToThisGame(payload)) return;
    showGoalBanner(payload);
    void recoverAuthoritativeState();
  });

  socket.on("game:lifecycle_updated", applyLifecyclePresentation);
  socket.on("lifecycle:updated", applyLifecyclePresentation);
  socket.on("game:phase_updated", applyLifecyclePresentation);

  socket.on("game:clock_updated", recoverIfThisGame);
  socket.on("clock:updated", recoverIfThisGame);
}

function installClockPrecisionResync() {
  window.setInterval(() => {
    void resyncAuthoritativeClock();
  }, CLOCK_RESYNC_MS);

  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") {
      void recoverAuthoritativeState();
    }
  });
}

async function bootstrap() {
  try {
    await loadAuthoritativeState();

    // Do not present a lifecycle banner simply because the page loaded.
    state.lastPresentedPhase = state.lifecycle?.phase || null;

    if (typeof window.io !== "function") {
      throw new Error("Socket.IO browser client is unavailable");
    }

    const socket = window.io({
      transports: ["websocket", "polling"],
      reconnection: true,
    });

    installSocketHandlers(socket);
    installClockPrecisionResync();
  } catch (error) {
    console.error("M11-F overlay bootstrap failed", error);
    byId("overlay-error").classList.remove("hidden");
  }
}

bootstrap();

window.setInterval(render, 250);
