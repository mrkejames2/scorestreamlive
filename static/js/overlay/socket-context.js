(function installOverlaySocketContext() {
  if (typeof window.io !== "function") return;

  const originalIo = window.io;
  const gameId = document.body?.dataset?.gameId;
  if (!gameId) return;

  function withGameAuth(options) {
    return {
      ...(options || {}),
      auth: {
        ...((options && options.auth) || {}),
        game_id: String(gameId),
        audience: "overlay",
      },
    };
  }

  function scopedIo(uriOrOptions, maybeOptions) {
    if (typeof uriOrOptions === "string") {
      return originalIo(uriOrOptions, withGameAuth(maybeOptions));
    }
    return originalIo(withGameAuth(uriOrOptions));
  }

  // Preserve Socket.IO client constructors/properties for compatibility.
  Object.assign(scopedIo, originalIo);
  window.io = scopedIo;
})();
