const byId = (id) => document.getElementById(id);

const gameId = String(document.body?.dataset?.gameId || "");
const surface = String(document.body?.dataset?.summarySurface || "summary");
const REFRESH_MS = 20000;
const DEFAULT_PRIMARY = "#2A77FF";
const DEFAULT_SECONDARY = "#FFFFFF";

function api(path) {
  return fetch(path, {
    method: "GET",
    headers: { Accept: "application/json" },
    cache: "no-store",
  }).then(async (response) => {
    if (!response.ok) throw new Error(`${path} returned HTTP ${response.status}`);
    return response.json();
  });
}

function normalizedColor(value, fallback) {
  const raw = String(value || "").trim();
  return /^#[0-9A-Fa-f]{6}$/.test(raw) ? raw.toUpperCase() : fallback;
}

function teamInitials(team, fallback) {
  const source = String(team?.short_name || team?.name || fallback).trim();
  const words = source.split(/\s+/).filter(Boolean);
  if (words.length >= 2) return `${words[0][0]}${words[1][0]}`.toUpperCase();
  return source.slice(0, 3).toUpperCase() || fallback;
}

function applyTeam(side, team) {
  const card = byId(`${side}-team-card`);
  const logo = byId(`${side}-logo`);
  const fallback = byId(`${side}-logo-fallback`);
  const name = byId(`${side}-name`);
  const label = side === "home" ? "HOME" : "AWAY";

  const primary = normalizedColor(team?.primary_color, DEFAULT_PRIMARY);
  const secondary = normalizedColor(team?.secondary_color, DEFAULT_SECONDARY);

  card?.style.setProperty("--team-primary", primary);
  card?.style.setProperty("--team-secondary", secondary);
  if (name) name.textContent = team?.short_name || team?.name || label;
  if (fallback) fallback.textContent = teamInitials(team, label);

  const logoUrl = String(team?.logo_url || "").trim();
  if (!logo || !fallback) return;
  if (!logoUrl) {
    logo.removeAttribute("src");
    logo.alt = "";
    logo.classList.add("hidden");
    fallback.classList.remove("hidden");
    return;
  }

  logo.src = logoUrl;
  logo.alt = `${team?.name || label} logo`;
  logo.classList.remove("hidden");
  fallback.classList.add("hidden");
  logo.onerror = () => {
    logo.classList.add("hidden");
    fallback.classList.remove("hidden");
  };
}

function phaseLabel(game) {
  if (game?.is_final) return "FINAL";
  const labels = {
    pregame: "PREGAME",
    first_half: "1ST HALF",
    halftime: "HALFTIME",
    second_half: "2ND HALF",
    full_time: "FINAL",
  };
  const phase = String(game?.phase || "pregame");
  return labels[phase] || phase.replaceAll("_", " ").toUpperCase();
}

function scheduledLabel(value) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return date.toLocaleString([], {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

function eventTeamName(event, data) {
  if (event?.team_side === "home") return data.home_team?.short_name || data.home_team?.name || "HOME";
  if (event?.team_side === "away") return data.away_team?.short_name || data.away_team?.name || "AWAY";
  return "TEAM";
}

function buildEventRow(event, data) {
  const row = document.createElement("div");
  row.className = surface === "broadcast" ? "broadcast-scoring-row" : "scoring-row";

  const minute = document.createElement("span");
  minute.className = "scoring-minute";
  minute.textContent = event?.minute == null ? "—" : `${event.minute}'`;

  const scorer = document.createElement("span");
  scorer.className = "scoring-scorer";
  const jersey = event?.jersey_number == null || String(event.jersey_number).trim() === ""
    ? ""
    : `#${event.jersey_number} `;
  scorer.textContent = `${jersey}${event?.scorer_name || "Unknown scorer"}`;

  const team = document.createElement("span");
  team.className = "scoring-team";
  team.textContent = eventTeamName(event, data);

  row.append(minute, scorer, team);
  return row;
}

function renderScoringEvents(data) {
  const host = byId("scoring-events");
  const empty = byId("no-scoring-events");
  if (!host || !empty) return;

  host.replaceChildren();
  const events = Array.isArray(data?.scoring_events) ? data.scoring_events : [];
  empty.classList.toggle("hidden", events.length !== 0);
  for (const event of events) {
    host.appendChild(buildEventRow(event, data));
  }
}

function render(data) {
  const game = data?.game || {};
  byId("summary-phase").textContent = phaseLabel(game);
  byId("summary-game-name").textContent = game.name || "";
  byId("summary-scheduled").textContent = scheduledLabel(game.scheduled_at);
  byId("home-score").textContent = String(game.home_score ?? 0);
  byId("away-score").textContent = String(game.away_score ?? 0);

  applyTeam("home", data?.home_team);
  applyTeam("away", data?.away_team);
  renderScoringEvents(data);

  byId("summary-error")?.classList.add("hidden");
  byId("summary-shell")?.classList.remove("summary-loading");
}

let refreshInFlight = false;

async function refresh() {
  if (refreshInFlight || !gameId) return;
  refreshInFlight = true;
  try {
    const data = await api(`/api/public/games/${gameId}/summary`);
    render(data);
  } catch (error) {
    console.error("M17-C public summary refresh failed", error);
    byId("summary-error")?.classList.remove("hidden");
  } finally {
    refreshInFlight = false;
  }
}

function installSocketRefresh() {
  if (typeof window.io !== "function" || !gameId) return;

  const socket = window.io({
    auth: {
      game_id: gameId,
      audience: "overlay",
    },
  });

  const relevant = [
    "game:updated",
    "game:score_updated",
    "scoring_event:created",
    "scoring_event:updated",
    "scoring_event:deleted",
    "scoring_event:corrected",
    "game:lifecycle_updated",
    "lifecycle:updated",
    "game:phase_updated",
  ];

  for (const eventName of relevant) {
    socket.on(eventName, (payload) => {
      const payloadGameId = String(payload?.game_id || payload?.id || "");
      if (payloadGameId === gameId) void refresh();
    });
  }

  socket.on("connect", () => void refresh());
}

async function bootstrap() {
  await refresh();
  installSocketRefresh();
  window.setInterval(() => void refresh(), REFRESH_MS);
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") void refresh();
  });
}

void bootstrap();
