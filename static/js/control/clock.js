let clockAnchorElapsedSeconds = 0;
let clockAnchorPerformanceMs = null;

function parseTimestamp(value) {
  if (!value) return null;
  const result = Date.parse(value);
  return Number.isFinite(result) ? result : null;
}

function snapshotElapsedSeconds(clockState) {
  if (!clockState) return 0;

  const authoritative = Number(clockState.authoritative_elapsed_seconds);
  if (Number.isFinite(authoritative)) {
    return Math.max(Math.floor(authoritative), 0);
  }

  let elapsed = Number(clockState.elapsed_seconds || 0);

  // Fallback for older clock payloads that do not include
  // authoritative_elapsed_seconds. Use server timestamps from the same
  // payload so browser wall-clock skew cannot affect the snapshot.
  if (clockState.status === "running" && clockState.running_since) {
    const runningSinceMs = parseTimestamp(clockState.running_since);
    const serverMs = parseTimestamp(clockState.server_time);

    if (runningSinceMs !== null && serverMs !== null) {
      elapsed += Math.max(
        Math.floor((serverMs - runningSinceMs) / 1000),
        0,
      );
    }
  }

  return Math.max(Math.floor(elapsed), 0);
}

export function updateServerOffset(clockState) {
  // Historical function name retained for compatibility with the Control
  // Center. M11-F precision cleanup now captures a monotonic clock anchor
  // instead of depending on Date.now() after the authoritative snapshot.
  clockAnchorElapsedSeconds = snapshotElapsedSeconds(clockState);
  clockAnchorPerformanceMs = performance.now();
}

export function authoritativeElapsedSeconds(clockState) {
  if (!clockState) return 0;

  let elapsed = clockAnchorElapsedSeconds;

  if (
    clockState.status === "running"
    && clockAnchorPerformanceMs !== null
  ) {
    elapsed += Math.max(
      Math.floor(
        (performance.now() - clockAnchorPerformanceMs) / 1000,
      ),
      0,
    );
  }

  return Math.max(Math.floor(elapsed), 0);
}

export function displaySeconds(clockState) {
  const elapsed = authoritativeElapsedSeconds(clockState);

  if (clockState?.mode === "count_down") {
    return Math.max(
      Number(clockState.duration_seconds || 0) - elapsed,
      0,
    );
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
