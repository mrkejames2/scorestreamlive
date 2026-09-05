/* ScoreStreamLive M17-G overlay presentation selector.
   Presentation only: no game, clock, scoring, socket, or recovery state is changed.
   Default: compact. Optional: ?layout=standard
*/
(() => {
  const params = new URLSearchParams(window.location.search);
  const requested = String(params.get("layout") || "compact").trim().toLowerCase();
  const layout = requested === "standard" ? "standard" : "compact";
  document.body.dataset.overlayLayout = layout;
  document.documentElement.dataset.overlayLayout = layout;
})();
