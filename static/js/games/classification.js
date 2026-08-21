export const GameLibraryClassification = Object.freeze({
  UPCOMING: "upcoming",
  LIVE: "live",
  COMPLETED: "completed",
  CANCELLED: "cancelled",
});

const LIVE_PHASES = new Set(["first_half", "halftime", "second_half"]);

export function classifyGame(game, lifecycle, clock) {
  const gameStatus = String(game?.status || "").toLowerCase();
  const lifecyclePhase = String(lifecycle?.phase || "").toLowerCase();
  const clockStatus = String(clock?.status || "").toLowerCase();

  if (gameStatus === "cancelled") return GameLibraryClassification.CANCELLED;
  if (lifecyclePhase === "full_time") return GameLibraryClassification.COMPLETED;
  if (LIVE_PHASES.has(lifecyclePhase)) return GameLibraryClassification.LIVE;
  if (lifecyclePhase === "pregame") return GameLibraryClassification.UPCOMING;
  if (clockStatus === "running") return GameLibraryClassification.LIVE;
  if (gameStatus === "completed") return GameLibraryClassification.COMPLETED;
  if (gameStatus === "live") return GameLibraryClassification.LIVE;
  return GameLibraryClassification.UPCOMING;
}
