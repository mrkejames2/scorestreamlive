const qs = (s, root=document) => root.querySelector(s);
const qsa = (s, root=document) => [...root.querySelectorAll(s)];

async function api(path, options={}) {
  const response = await fetch(path, {
    cache: "no-store",
    headers: { Accept: "application/json", ...(options.headers || {}) },
    ...options,
  });
  let body = null;
  try { body = await response.json(); } catch (_) {}
  if (!response.ok) {
    const detail = typeof body?.detail === "string" ? body.detail : `HTTP ${response.status}`;
    throw new Error(detail);
  }
  return body;
}

function flash(message, kind="info") {
  let el = document.getElementById("m17b-lifecycle-flash");
  if (!el) {
    el = document.createElement("div");
    el.id = "m17b-lifecycle-flash";
    el.className = "m17b-lifecycle-flash";
    document.body.appendChild(el);
  }
  el.dataset.kind = kind;
  el.textContent = message;
  el.classList.add("is-visible");
  clearTimeout(flash._timer);
  flash._timer = setTimeout(() => el.classList.remove("is-visible"), 5000);
}

function confirmAction(label, name, destructive=false) {
  const suffix = destructive
    ? "\n\nThis is permanent and cannot be undone."
    : "\n\nYou can restore it later.";
  return window.confirm(`${label} "${name}"?${suffix}`);
}

function makeButton(label, className, handler) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = `button ${className} m17b-lifecycle-action`;
  button.textContent = label;
  button.addEventListener("click", handler);
  return button;
}

function installModeToggle(host, label) {
  if (document.getElementById("m17b-lifecycle-toggle")) return;
  const wrap = document.createElement("div");
  wrap.id = "m17b-lifecycle-toggle";
  wrap.className = "m17b-lifecycle-toggle";
  wrap.innerHTML = `
    <span class="m17b-lifecycle-label">${label}</span>
    <button type="button" class="button button-secondary is-selected" data-m17b-mode="active">Active</button>
    <button type="button" class="button button-secondary" data-m17b-mode="archived">Archived</button>
  `;
  host.prepend(wrap);
}

async function performLifecycle(kind, id, action, name) {
  const destructive = action === "delete";
  const verb = action === "delete" ? "Permanently delete" : action[0].toUpperCase() + action.slice(1);
  if (!confirmAction(verb, name || kind, destructive)) return false;

  const path = `/api/${kind}/${id}${action === "delete" ? "" : `/${action}`}`;
  try {
    await api(path, { method: action === "delete" ? "DELETE" : "POST" });
    flash(`${name || kind} ${action === "delete" ? "deleted" : `${action}d`} successfully.`, "success");
    return true;
  } catch (error) {
    flash(error.message || `Unable to ${action} ${kind}.`, "error");
    return false;
  }
}

function teamName(card) {
  return qs(".team-name", card)?.textContent?.trim() || "Team";
}

function gameName(card) {
  return qs(".game-name", card)?.textContent?.trim() || "Game";
}

function decorateActiveTeamCards() {
  for (const card of qsa(".team-card[data-team-id]")) {
    if (card.dataset.m17bLifecycleDecorated === "1") continue;
    card.dataset.m17bLifecycleDecorated = "1";
    const group = qs(".team-action-group", card) || qs(".team-card-actions", card);
    if (!group) continue;
    const id = card.dataset.teamId;
    group.append(
      makeButton("Archive", "button-secondary", async () => {
        if (await performLifecycle("teams", id, "archive", teamName(card))) location.reload();
      }),
      makeButton("Delete", "button-danger", async () => {
        if (await performLifecycle("teams", id, "delete", teamName(card))) location.reload();
      }),
    );
  }
}

function decorateActiveGameCards() {
  for (const card of qsa(".game-card[data-game-id]")) {
    if (card.dataset.m17bLifecycleDecorated === "1") continue;
    card.dataset.m17bLifecycleDecorated = "1";
    const id = card.dataset.gameId;
    const box = document.createElement("div");
    box.className = "m17b-card-actions";
    box.append(
      makeButton("Archive", "button-secondary", async () => {
        if (await performLifecycle("games", id, "archive", gameName(card))) location.reload();
      }),
      makeButton("Delete", "button-danger", async () => {
        if (await performLifecycle("games", id, "delete", gameName(card))) location.reload();
      }),
    );
    card.appendChild(box);
  }
}

function genericArchivedCard(kind, item) {
  const card = document.createElement("article");
  card.className = "m17b-archived-card";
  const name = item.name || (kind === "teams" ? "Unnamed Team" : "Untitled Game");
  const archivedAt = item.archived_at ? new Date(item.archived_at).toLocaleString() : "Unknown";
  const detail = kind === "teams"
    ? (item.short_name || item.id)
    : `${item.home_score ?? 0} - ${item.away_score ?? 0}`;

  card.innerHTML = `
    <div>
      <span class="m17b-archived-badge">ARCHIVED</span>
      <h3></h3>
      <p class="m17b-archived-detail"></p>
      <small>Archived ${archivedAt}</small>
    </div>
    <div class="m17b-card-actions"></div>
  `;
  qs("h3", card).textContent = name;
  qs(".m17b-archived-detail", card).textContent = detail;
  const actions = qs(".m17b-card-actions", card);

  if (kind === "teams") {
    const view = document.createElement("a");
    view.href = `/teams/${item.id}`;
    view.className = "button button-secondary";
    view.textContent = "View";
    actions.appendChild(view);
  }

  actions.append(
    makeButton("Restore", "button-primary", async () => {
      if (await performLifecycle(kind, item.id, "restore", name)) await showArchived(kind);
    }),
    makeButton("Delete", "button-danger", async () => {
      if (await performLifecycle(kind, item.id, "delete", name)) await showArchived(kind);
    }),
  );
  return card;
}

async function showArchived(kind) {
  const archivedHost = document.getElementById("m17b-archived-list");
  if (!archivedHost) return;
  archivedHost.replaceChildren();
  archivedHost.innerHTML = `<p class="m17b-loading">Loading archived ${kind}…</p>`;
  try {
    const items = await api(`/api/${kind}?archived=true`);
    archivedHost.replaceChildren();
    if (!Array.isArray(items) || items.length === 0) {
      archivedHost.innerHTML = `<div class="m17b-empty">No archived ${kind}.</div>`;
      return;
    }
    items.forEach(item => archivedHost.appendChild(genericArchivedCard(kind, item)));
  } catch (error) {
    archivedHost.innerHTML = `<div class="m17b-empty m17b-error"></div>`;
    qs(".m17b-error", archivedHost).textContent = error.message || `Unable to load archived ${kind}.`;
  }
}

function installArchivedHost(activeHost, kind) {
  let archivedHost = document.getElementById("m17b-archived-list");
  if (archivedHost) return archivedHost;
  archivedHost = document.createElement("section");
  archivedHost.id = "m17b-archived-list";
  archivedHost.className = "m17b-archived-list hidden";
  archivedHost.dataset.kind = kind;
  activeHost.insertAdjacentElement("afterend", archivedHost);
  return archivedHost;
}

function setMode(kind, mode, activeContainer) {
  qsa("[data-m17b-mode]").forEach(button => {
    button.classList.toggle("is-selected", button.dataset.m17bMode === mode);
  });
  const archived = document.getElementById("m17b-archived-list");
  activeContainer.classList.toggle("m17b-hidden-view", mode === "archived");
  archived?.classList.toggle("hidden", mode !== "archived");
  if (mode === "archived") showArchived(kind);
}

function bootTeams() {
  const panel = qs(".teams-panel");
  const active = qs("#teams-list");
  if (!panel || !active) return;
  installModeToggle(panel, "Team View");
  installArchivedHost(active, "teams");
  qsa("[data-m17b-mode]").forEach(button => {
    button.addEventListener("click", () => setMode("teams", button.dataset.m17bMode, active));
  });
  decorateActiveTeamCards();
  new MutationObserver(decorateActiveTeamCards).observe(document.body, { childList: true, subtree: true });
}

function bootGames() {
  const panel = qs(".games-panel");
  const active = qs("#library-sections") || panel;
  if (!panel || !active) return;
  installModeToggle(panel, "Game View");
  installArchivedHost(active, "games");
  qsa("[data-m17b-mode]").forEach(button => {
    button.addEventListener("click", () => setMode("games", button.dataset.m17bMode, active));
  });
  decorateActiveGameCards();
  new MutationObserver(decorateActiveGameCards).observe(document.body, { childList: true, subtree: true });
}

if (location.pathname === "/teams") bootTeams();
if (location.pathname === "/games") bootGames();
