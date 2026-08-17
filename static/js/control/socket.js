import { setLastLiveEvent, setSocketConnected } from "./state.js";

function isCurrentGame(payload, gameId) {
  return payload && String(payload.game_id) === String(gameId);
}

export function connectControlSocket({
  gameId,
  onConnected,
  onDisconnected,
  onReconnectAttempt,
  onScoreUpdated,
  onScoringEventCreated,
  onPhaseUpdated,
  onClockUpdated,
  onAuthoritativeRefresh,
}) {
  if (typeof window.io !== "function") {
    throw new Error(
      "Socket.IO browser client is not loaded. Expected /static/vendor/socket.io.min.js",
    );
  }

  const socket = window.io(window.location.origin, {
    path: "/socket.io",
    transports: ["polling", "websocket"],
    reconnection: true,
    reconnectionAttempts: Infinity,
    reconnectionDelay: 500,
    reconnectionDelayMax: 5000,
    timeout: 10000,
  });

  socket.on("connect", async () => {
    setSocketConnected(true);
    onConnected?.();
    try {
      await onAuthoritativeRefresh?.();
    } catch (error) {
      console.error("Authoritative refresh after socket connect failed", error);
    }
  });

  socket.on("disconnect", () => {
    setSocketConnected(false);
    onDisconnected?.();
  });

  socket.io.on("reconnect_attempt", () => {
    setSocketConnected(false);
    onReconnectAttempt?.();
  });

  socket.on("game:score_updated", (payload) => {
    if (!isCurrentGame(payload, gameId)) return;
    setLastLiveEvent("game:score_updated");
    onScoreUpdated?.(payload);
  });

  socket.on("scoring_event:created", (payload) => {
    if (!isCurrentGame(payload, gameId)) return;
    setLastLiveEvent("scoring_event:created");
    onScoringEventCreated?.(payload);
  });

  socket.on("game:phase_updated", (payload) => {
    if (!isCurrentGame(payload, gameId)) return;
    setLastLiveEvent("game:phase_updated");
    onPhaseUpdated?.(payload);
  });

  socket.on("clock:updated", (payload) => {
    if (!isCurrentGame(payload, gameId)) return;
    setLastLiveEvent("clock:updated");
    onClockUpdated?.(payload);
  });

  return socket;
}
