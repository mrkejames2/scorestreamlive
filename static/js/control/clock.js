let serverOffsetMs = 0;

function parseTimestamp(value) {
  if (!value) return null;
  const result = Date.parse(value);
  return Number.isFinite(result) ? result : null;
}

export function updateServerOffset(clockState) {
  const serverMs = parseTimestamp(clockState?.server_time);
  serverOffsetMs = serverMs === null ? 0 : serverMs - Date.now();
}

function estimatedServerNowMs() {
  return Date.now() + serverOffsetMs;
}

export function authoritativeElapsedSeconds(clockState) {
  if (!clockState) return 0;

  let elapsed = Number(clockState.elapsed_seconds || 0);

  if (clockState.status === "running" && clockState.running_since) {
    const runningSinceMs = parseTimestamp(clockState.running_since);
    if (runningSinceMs !== null) {
      elapsed += Math.max(
        Math.floor((estimatedServerNowMs() - runningSinceMs) / 1000),
        0,
      );
    }
  }

  return Math.max(Math.floor(elapsed), 0);
}

export function displaySeconds(clockState) {
  const elapsed = authoritativeElapsedSeconds(clockState);
  if (clockState?.mode === "count_down") {
    return Math.max(Number(clockState.duration_seconds || 0) - elapsed, 0);
  }
  return elapsed;
}

export function formatClock(seconds) {
  const safe = Math.max(Math.floor(Number(seconds) || 0), 0);
  const minutes = Math.floor(safe / 60);
  const remainingSeconds = safe % 60;
  return `${minutes}:${String(remainingSeconds).padStart(2, "0")}`;
}

export function soccerAddedTimeMinute(clockState) {
  if (!clockState || clockState.mode !== "count_up") return null;
  const elapsed = authoritativeElapsedSeconds(clockState);
  const duration = Number(clockState.duration_seconds || 0);
  if (duration <= 0 || elapsed < duration) return null;
  return Math.floor((elapsed - duration) / 60) + 1;
}
