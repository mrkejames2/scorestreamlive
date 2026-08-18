const byId = (id) => document.getElementById(id);

const gameId = document.body.dataset.gameId;

const CLOCK_RESYNC_MS = 5000;

const state = {
  game: null,
  homeTeam: null,
  awayTeam: null,
  lifecycle: null,
  clock: null,

  // M11-C clock anchor:
  // authoritative elapsed value captured from the server plus a monotonic
  // browser timestamp. performance.now() is intentionally used so system
  // clock changes cannot move the displayed match clock.
  clockAnchorElapsed: 0,
  clockAnchorPerformanceMs: null,

  socketConnected: false,
  recovering: false,
  clockResyncing: false,
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
  return String(value || "pregame").replaceAll("_", " ").toUpperCase();
}

function clampElapsed(value) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.max(0, Math.floor(n)) : 0;
}

function authoritativeElapsed(clock) {
  if (!clock) return 0;

  const direct = Number(clock.authoritative_elapsed_seconds);
  if (Number.isFinite(direct)) {
    return Math.max(0, direct);
  }

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
      Math.floor(
        (performance.now() - state.clockAnchorPerformanceMs) / 1000,
      ),
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

function render() {
  if (!state.game) return;

  byId("home-team-name").textContent =
    state.homeTeam?.short_name || state.homeTeam?.name || "HOME";

  byId("away-team-name").textContent =
    state.awayTeam?.short_name || state.awayTeam?.name || "AWAY";

  byId("home-score").textContent =
    String(state.game.home_score ?? 0);

  byId("away-score").textContent =
    String(state.game.away_score ?? 0);

  byId("phase-display").textContent =
    phaseLabel(state.lifecycle?.phase);

  byId("clock-display").textContent =
    formatClock(clockSecondsForDisplay());
}

function eventGameId(payload) {
  return String(payload?.game_id || payload?.id || "");
}

function belongsToThisGame(payload) {
  return eventGameId(payload) === String(gameId);
}

async function loadAuthoritativeState() {
  const game = await api(`/api/games/${gameId}`);

  const [homeTeam, awayTeam, lifecycle, clock] = await Promise.all([
    api(`/api/teams/${game.home_team_id}`),
    api(`/api/teams/${game.away_team_id}`),
    api(`/api/games/${gameId}/lifecycle`),
    api(`/api/games/${gameId}/clock`),
  ]);

  state.game = game;
  state.homeTeam = homeTeam;
  state.awayTeam = awayTeam;
  state.lifecycle = lifecycle;
  state.clock = clock;

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
    console.error("M11-C clock-only authoritative resync failed", error);
  } finally {
    state.clockResyncing = false;
  }
}

async function recoverAuthoritativeState() {
  if (state.recovering) return;

  state.recovering = true;

  try {
    await loadAuthoritativeState();
  } catch (error) {
    console.error("M11-C authoritative recovery failed", error);
    byId("overlay-error").classList.remove("hidden");
  } finally {
    state.recovering = false;
  }
}

function installSocketHandlers(socket) {
  socket.on("connect", async () => {
    state.socketConnected = true;
    await recoverAuthoritativeState();
  });

  socket.on("disconnect", () => {
    state.socketConnected = false;
  });

  socket.io.on("reconnect_attempt", () => {
    state.socketConnected = false;
  });

  // Socket.IO domain events are invalidation signals. REST remains the
  // canonical committed-state recovery path.
  const recoverIfThisGame = (payload) => {
    if (belongsToThisGame(payload)) {
      void recoverAuthoritativeState();
    }
  };

  socket.on("game:score_updated", recoverIfThisGame);
  socket.on("scoring_event:created", recoverIfThisGame);
  socket.on("game:lifecycle_updated", recoverIfThisGame);
  socket.on("lifecycle:updated", recoverIfThisGame);
  socket.on("game:phase_updated", recoverIfThisGame);
  socket.on("game:clock_updated", recoverIfThisGame);
  socket.on("clock:updated", recoverIfThisGame);
}

function installClockPrecisionResync() {
  // Five-second clock-only polling keeps the broadcast display tightly
  // aligned to server authority without reloading game/team/roster state.
  window.setInterval(() => {
    void resyncAuthoritativeClock();
  }, CLOCK_RESYNC_MS);

  // OBS/Streamlabs/browser tabs may be suspended or backgrounded.
  // Immediately recover the complete authoritative state when visible again.
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") {
      void recoverAuthoritativeState();
    }
  });
}

async function bootstrap() {
  try {
    await loadAuthoritativeState();

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
    console.error("M11-C overlay bootstrap failed", error);
    byId("overlay-error").classList.remove("hidden");
  }
}

bootstrap();

// Smooth visual rendering is entirely local.
// Server state remains authoritative; there is no per-second socket tick.
window.setInterval(render, 250);
