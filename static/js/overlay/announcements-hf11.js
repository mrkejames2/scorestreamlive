const gameId = document.body.dataset.gameId;
const root = document.getElementById("hf11-lower-third");
const number = document.getElementById("hf11-number");
const name = document.getElementById("hf11-name");
const subtitle = document.getElementById("hf11-subtitle");
const kicker = document.getElementById("hf11-kicker");
let version = -1;
let active = null;
let latest = null;

function reconcile(state) {
  if (!state || Number(state.version) < version) return;
  version = Number(state.version);
  latest = state;
  const item = state.items?.find(i => i.id === state.active_id);
  const shouldShow = Boolean(state.visible && item);
  if (shouldShow) {
    number.textContent = item.number ? `#${item.number}` : "";
    number.hidden = !item.number;
    name.textContent = item.name;
    subtitle.textContent = item.subtitle || "";
    kicker.textContent = state.title || "LIVE EVENT";
  }
  const key = shouldShow ? `${state.active_id}:${state.version}` : null;
  if (key !== active) {
    root.classList.toggle("hf11-visible", shouldShow);
    root.setAttribute("aria-hidden", shouldShow ? "false" : "true");
    active = key;
  }
}
async function recover() {
  try {
    const response = await fetch(`/api/public/games/${encodeURIComponent(gameId)}/announcements`, {cache:"no-store"});
    if (response.ok) reconcile(await response.json());
  } catch (error) { console.warn("HF11 recovery pending", error); }
}
await recover();
if (typeof window.io === "function") {
  const socket = window.io({auth:{game_id:gameId,audience:"overlay"}, transports:["polling","websocket"]});
  socket.on("announcement:presentation_updated", data => {
    if (String(data.game_id) === String(gameId)) reconcile(data);
  });
  socket.on("connect", () => { version = -1; void recover(); });
}
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") { version = -1; void recover(); }
});
setInterval(() => { version = -1; void recover(); }, 15000);
