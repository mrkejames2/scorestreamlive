const byId = (id) => document.getElementById(id);

const gameId = document.body.dataset.gameId;

const state = {
  game: null,
  homeTeam: null,
  awayTeam: null,
  homeRoster: [],
  awayRoster: [],
  lifecycle: null,
  clock: null,
};

function setStatus(label, status) {
  const node = byId("detail-status");
  node.textContent = label;
  node.dataset.state = status;
}

async function api(path, allow404 = false) {
  const response = await fetch(path, {
    method: "GET",
    headers: { "Accept": "application/json" },
    cache: "no-store",
  });

  if (allow404 && response.status === 404) return null;
  if (!response.ok) throw new Error(`${path} returned HTTP ${response.status}`);
  return response.json();
}

function normalizedColor(value, fallback) {
  const raw = String(value || "").trim();
  return /^#[0-9A-Fa-f]{6}$/.test(raw) ? raw.toUpperCase() : fallback;
}

function teamInitials(team, fallback) {
  const source = String(team?.short_name || team?.name || fallback).trim();
  if (!source) return fallback.slice(0, 1);

  const words = source.split(/\s+/).filter(Boolean);
  if (words.length >= 2) return `${words[0][0]}${words[1][0]}`.toUpperCase();
  return source.slice(0, 3).toUpperCase();
}

function renderTeamBrand(side, team) {
  const card = byId(`${side}-team-card`);
  const shell = byId(`${side}-brand`);
  const logo = byId(`${side}-brand-logo`);
  const fallback = byId(`${side}-brand-fallback`);

  const primary = normalizedColor(team?.primary_color, "#2A77FF");
  const secondary = normalizedColor(team?.secondary_color, "#FFFFFF");

  card.style.setProperty("--team-primary", primary);
  card.style.setProperty("--team-secondary", secondary);
  shell.style.setProperty("--team-primary", primary);
  shell.style.setProperty("--team-secondary", secondary);

  fallback.textContent = teamInitials(team, side === "home" ? "HOME" : "AWAY");

  const logoUrl = String(team?.logo_url || "").trim();

  if (!logoUrl) {
    logo.removeAttribute("src");
    logo.alt = "";
    logo.classList.add("hidden");
    fallback.classList.remove("hidden");
    return;
  }

  logo.src = logoUrl;
  logo.alt = `${team?.name || "Team"} logo`;
  logo.classList.remove("hidden");
  fallback.classList.add("hidden");

  logo.onerror = () => {
    logo.classList.add("hidden");
    fallback.classList.remove("hidden");
  };
}

function phaseLabel(value) {
  const phase = String(value || "not_initialized");
  const labels = {
    pregame: "Pregame",
    first_half: "1st Half",
    halftime: "Halftime",
    second_half: "2nd Half",
    full_time: "Full Time",
    not_initialized: "Not Initialized",
  };
  return labels[phase] || phase.replaceAll("_", " ");
}

function clockSeconds(clock) {
  if (!clock) return null;

  const value = Number(
    clock.display_seconds
    ?? clock.authoritative_elapsed_seconds
    ?? clock.elapsed_seconds,
  );

  return Number.isFinite(value) ? Math.max(0, Math.floor(value)) : 0;
}

function formatClock(clock) {
  const seconds = clockSeconds(clock);
  if (seconds === null) return "—:—";

  const minutes = Math.floor(seconds / 60);
  const remainder = seconds % 60;
  return `${minutes}:${String(remainder).padStart(2, "0")}`;
}

function clockStatusLabel(clock) {
  if (!clock) return "Clock Not Initialized";

  return String(clock.status || "unknown")
    .replaceAll("_", " ")
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function render() {
  const { game, homeTeam, awayTeam, homeRoster, awayRoster, lifecycle, clock } = state;

  byId("game-name").textContent = game.name || "Game Detail";
  byId("home-team-name").textContent = homeTeam.short_name || homeTeam.name || "HOME";
  byId("away-team-name").textContent = awayTeam.short_name || awayTeam.name || "AWAY";
  byId("home-score").textContent = String(game.home_score ?? 0);
  byId("away-score").textContent = String(game.away_score ?? 0);

  const homeCount = homeRoster.length;
  const awayCount = awayRoster.length;

  byId("home-roster-summary").textContent = `${homeCount} player${homeCount === 1 ? "" : "s"}`;
  byId("away-roster-summary").textContent = `${awayCount} player${awayCount === 1 ? "" : "s"}`;
  byId("home-roster-count").textContent = String(homeCount);
  byId("away-roster-count").textContent = String(awayCount);

  byId("phase-display").textContent = phaseLabel(lifecycle?.phase).toUpperCase();
  byId("clock-display").textContent = formatClock(clock);
  byId("clock-status").textContent = clockStatusLabel(clock);

  byId("lifecycle-readiness").textContent =
    lifecycle ? phaseLabel(lifecycle.phase) : "Not Initialized";
  byId("lifecycle-version").textContent =
    lifecycle?.version ? `Version ${lifecycle.version}` : "No lifecycle state";

  byId("clock-readiness").textContent =
    clock ? clockStatusLabel(clock) : "Not Initialized";
  byId("clock-mode").textContent =
    clock?.mode ? String(clock.mode).replaceAll("_", " ") : "No clock state";

  renderTeamBrand("home", homeTeam);
  renderTeamBrand("away", awayTeam);

  byId("control-link").href = `/control/games/${game.id}`;
  byId("overlay-link").href = `/overlay/games/${game.id}`;
  byId("roster-link").href = `/games/${game.id}/setup`;

  byId("match-hero").classList.remove("hidden");
  byId("launch-panel").classList.remove("hidden");
  byId("readiness-grid").classList.remove("hidden");
}

async function loadState() {
  setStatus("LOADING", "loading");
  byId("detail-error").classList.add("hidden");

  try {
    const game = await api(`/api/games/${gameId}`);

    const [homeTeam, awayTeam, homeRoster, awayRoster, lifecycle, clock] =
      await Promise.all([
        api(`/api/teams/${game.home_team_id}`),
        api(`/api/teams/${game.away_team_id}`),
        api(`/api/teams/${game.home_team_id}/players`),
        api(`/api/teams/${game.away_team_id}/players`),
        api(`/api/games/${game.id}/lifecycle`, true),
        api(`/api/games/${game.id}/clock`, true),
      ]);

    Object.assign(state, {
      game,
      homeTeam,
      awayTeam,
      homeRoster,
      awayRoster,
      lifecycle,
      clock,
    });

    render();
    setStatus("READY", "ready");
  } catch (error) {
    console.error("M12-F Game Detail load failed", error);
    byId("detail-error").textContent =
      "Game Detail could not load authoritative state. " + error.message;
    byId("detail-error").classList.remove("hidden");
    setStatus("ERROR", "error");
  }
}

async function copyOverlayUrl() {
  if (!state.game) return;

  const overlayUrl = `${window.location.origin}/overlay/games/${state.game.id}`;

  try {
    await navigator.clipboard.writeText(overlayUrl);
  } catch (_) {
    const field = document.createElement("textarea");
    field.value = overlayUrl;
    field.setAttribute("readonly", "");
    field.style.position = "fixed";
    field.style.opacity = "0";
    document.body.appendChild(field);
    field.select();
    document.execCommand("copy");
    field.remove();
  }

  const notice = byId("copy-notice");
  notice.textContent = "Overlay URL copied to clipboard.";
  notice.classList.remove("hidden");

  window.setTimeout(() => {
    notice.classList.add("hidden");
  }, 2500);
}

byId("copy-overlay-url").addEventListener("click", () => void copyOverlayUrl());
byId("refresh-detail").addEventListener("click", () => void loadState());

void loadState();
