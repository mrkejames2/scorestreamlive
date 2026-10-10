const gameId = document.body.dataset.gameId;
const base = `/api/games/${encodeURIComponent(gameId)}/announcements`;
const el = id => document.getElementById(id);
let snapshot = null;
let busy = false;
let dirty = false;

function status(message, error = false) {
  el("hf11-status").textContent = message;
  el("hf11-status").style.color = error ? "#d54a4a" : "";
}
async function api(url, method = "GET", payload) {
  const response = await fetch(url, {
    method, cache: "no-store",
    headers: {"Accept":"application/json", ...(payload ? {"Content-Type":"application/json"} : {})},
    ...(payload ? {body:JSON.stringify(payload)} : {})
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(typeof result.detail === "string" ? result.detail : `HTTP ${response.status}`);
  return result;
}
function render() {
  if (!snapshot) return;
  el("hf11-title").value = snapshot.title;
  const list = el("hf11-list");
  list.replaceChildren();
  for (const item of snapshot.items) {
    const row = document.createElement("div");
    row.className = "hf11-item";
    const label = document.createElement("span");
    label.textContent = `${item.number ? "#"+item.number+"  " : ""}${item.name}${item.subtitle ? " — "+item.subtitle : ""}`;
    const show = document.createElement("button");
    show.type = "button"; show.className = "secondary-button";
    show.textContent = snapshot.visible && snapshot.active_id === item.id ? "On Air" : "Show";
    show.disabled = busy || dirty;
    show.addEventListener("click", () => void sendCommand("show", item.id));
    row.append(label, show);
    list.append(row);
  }
  const active = snapshot.items.find(i => i.id === snapshot.active_id);
  el("hf11-onair").textContent = snapshot.visible && active ? `ON AIR: ${active.name}` : "Off air";
  for (const id of ["hf11-next","hf11-previous","hf11-hide"]) el(id).disabled = busy || dirty;
}
async function refresh() {
  snapshot = await api(base);
  dirty = false;
  render();
}
async function run(fn) {
  if (busy) return;
  busy = true;
  status("Saving...");
  try {
    await fn();
    status("Ready");
  } catch (error) {
    status(`${error.message}. Refresh to recover.`, true);
  } finally {
    busy = false;
    render();
  }
}
async function sendCommand(action, item_id = null) {
  if (dirty) { status("Save the list before going live", true); return; }
  await run(async () => {
    snapshot = await api(`${base}/command`, "POST", {action, item_id, expected_version:snapshot.version});
  });
}
function editorItems() {
  return el("hf11-editor").value.split(/\r?\n/).map(line => line.trim()).filter(Boolean).map(line => {
    const [number = "", name = "", ...rest] = line.split("|");
    return {number:number.trim(), name:name.trim(), subtitle:rest.join("|").trim()};
  });
}
el("hf11-save").addEventListener("click", () => void run(async () => {
  const items = editorItems();
  if (items.some(i => !i.name)) throw new Error("Each line requires a name");
  snapshot = await api(base, "PUT", {title:el("hf11-title").value.trim() || "SENIOR NIGHT", items, expected_version:snapshot.version});
  dirty = false;
}));
el("hf11-refresh").addEventListener("click", () => void run(refresh));
el("hf11-next").addEventListener("click", () => void sendCommand("next"));
el("hf11-previous").addEventListener("click", () => void sendCommand("previous"));
el("hf11-hide").addEventListener("click", () => void sendCommand("hide"));
el("hf11-editor").addEventListener("input", () => {dirty = true; status("Unsaved list — save before going live");});
el("hf11-title").addEventListener("input", () => {dirty = true; status("Unsaved title — save before going live");});
el("hf11-load-editor").addEventListener("click", () => {
  if (!snapshot || !confirm("Replace the editor with the last saved announcement list?")) return;
  el("hf11-editor").value = snapshot.items.map(i => [i.number,i.name,i.subtitle].join(" | ")).join("\n");
  el("hf11-title").value = snapshot.title;
  dirty = false;
  status("Saved list loaded into editor");
  render();
});
window.addEventListener("online", () => { if (!dirty) void refresh().catch(() => status("Connection recovery failed", true)); });
void refresh().then(() => {
  el("hf11-editor").value = snapshot.items.map(i => [i.number,i.name,i.subtitle].join(" | ")).join("\n");
  status("Ready");
}).catch(error => status(error.message, true));
