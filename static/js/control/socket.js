import {
  setConnectionState,
  setLastLiveEvent,
  setSocketConnected,
  setStateAuthoritative,
} from "./state.js";

function isCurrentGame(payload, gameId) {
  return payload && String(payload.game_id) === String(gameId);
}

export function connectControlSocket({
  gameId,
  onTransportConnected,
  onReady,
  onDisconnected,
  onReconnectAttempt,
  onRecoveryStarted,
  onRecoveryFailed,
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

  let recoveryInFlight = false;

  async function recoverAuthoritativeState() {
    if (recoveryInFlight) return false;

    recoveryInFlight = true;
    setSocketConnected(false);
    setStateAuthoritative(false);
    setConnectionState("recovering");
    onRecoveryStarted?.();

    try {
      await onAuthoritativeRefresh?.();

      // A successful authoritative refresh is the gate that makes the
      // controller safe to mutate again.
      setStateAuthoritative(true);
      setSocketConnected(true);
      setConnectionState("live");
      onReady?.();
      return true;
    } catch (error) {
      setSocketConnected(false);
      setStateAuthoritative(false);
      setConnectionState("recovering");
      onRecoveryFailed?.(error);
      console.error("Authoritative recovery after socket connect failed", error);
      return false;
    } finally {
      recoveryInFlight = false;
    }
  }

  socket.on("connect", async () => {
    setSocketConnected(false);
    setStateAuthoritative(false);
    setConnectionState("recovering");
    onTransportConnected?.();
    await recoverAuthoritativeState();
  });

  socket.on("disconnect", () => {
    setSocketConnected(false);
    setStateAuthoritative(false);
    setConnectionState("offline");
    onDisconnected?.();
  });

  socket.io.on("reconnect_attempt", () => {
    setSocketConnected(false);
    setStateAuthoritative(false);
    setConnectionState("reconnecting");
    onReconnectAttempt?.();
  });

  socket.io.on("reconnect_error", () => {
    setSocketConnected(false);
    setStateAuthoritative(false);
    setConnectionState("reconnecting");
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

  return {
    socket,
    recoverAuthoritativeState,
  };
}
