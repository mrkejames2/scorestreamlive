const byId = (id) => document.getElementById(id);

const DEFAULT_PRIMARY = "#2A77FF";
const DEFAULT_SECONDARY = "#FFFFFF";

function gameIdFromPage() {
  return document.body.dataset.gameId;
}

async function getJson(path) {
  const response = await fetch(path, {
    method: "GET",
    headers: { "Accept": "application/json" },
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error(`${path} returned HTTP ${response.status}`);
  }

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
  if (words.length >= 2) {
    return `${words[0][0]}${words[1][0]}`.toUpperCase();
  }

  return source.slice(0, 3).toUpperCase();
}

function applyLogo({ shellId, logoId, fallbackId, team, fallback }) {
  const shell = byId(shellId);
  const logo = byId(logoId);
  const fallbackNode = byId(fallbackId);

  if (!shell || !logo || !fallbackNode) return;

  const primary = normalizedColor(team?.primary_color, DEFAULT_PRIMARY);
  const secondary = normalizedColor(team?.secondary_color, DEFAULT_SECONDARY);

  shell.style.setProperty("--team-primary", primary);
  shell.style.setProperty("--team-secondary", secondary);
  fallbackNode.textContent = teamInitials(team, fallback);

  const logoUrl = String(team?.logo_url || "").trim();

  if (!logoUrl) {
    logo.removeAttribute("src");
    logo.alt = "";
    logo.classList.add("hidden");
    fallbackNode.classList.remove("hidden");
    return;
  }

  logo.src = logoUrl;
  logo.alt = `${team?.name || fallback} logo`;
  logo.classList.remove("hidden");
  fallbackNode.classList.add("hidden");

  logo.onerror = () => {
    logo.classList.add("hidden");
    fallbackNode.classList.remove("hidden");
  };
}

function applyTeamBrand(side, team) {
  const prefix = side === "home" ? "home" : "away";
  const fallback = side === "home" ? "HOME" : "AWAY";

  const primary = normalizedColor(team?.primary_color, DEFAULT_PRIMARY);
  const secondary = normalizedColor(team?.secondary_color, DEFAULT_SECONDARY);

  document.body.style.setProperty(`--${prefix}-team-primary`, primary);
  document.body.style.setProperty(`--${prefix}-team-secondary`, secondary);

  const panel = byId(`${prefix}-control-team-panel`);
  if (panel) {
    panel.style.setProperty("--team-primary", primary);
    panel.style.setProperty("--team-secondary", secondary);
  }

  const scoringCard = byId(`${prefix}-scoring-card`);
  if (scoringCard) {
    scoringCard.style.setProperty("--team-primary", primary);
    scoringCard.style.setProperty("--team-secondary", secondary);
  }

  const shortName = byId(`${prefix}-control-short-name`);
  if (shortName) {
    const value = String(team?.short_name || "").trim();
    shortName.textContent =
      value && value !== String(team?.name || "").trim()
        ? value
        : "";
  }

  applyLogo({
    shellId: `${prefix}-control-logo-shell`,
    logoId: `${prefix}-control-logo`,
    fallbackId: `${prefix}-control-logo-fallback`,
    team,
    fallback,
  });

  applyLogo({
    shellId: `${prefix}-scoring-logo-shell`,
    logoId: `${prefix}-scoring-logo`,
    fallbackId: `${prefix}-scoring-logo-fallback`,
    team,
    fallback,
  });
}

async function loadControlBranding() {
  const gameId = gameIdFromPage();

  try {
    const game = await getJson(`/api/games/${gameId}`);

    const [homeTeam, awayTeam] = await Promise.all([
      getJson(`/api/teams/${game.home_team_id}`),
      getJson(`/api/teams/${game.away_team_id}`),
    ]);

    applyTeamBrand("home", homeTeam);
    applyTeamBrand("away", awayTeam);

    document.body.dataset.brandingState = "ready";
  } catch (error) {
    // Branding is presentation-only. Never block authoritative Control Center
    // operation if branding cannot be loaded.
    console.error("M12-D5 Team branding load failed", error);
    document.body.dataset.brandingState = "fallback";
  }
}

void loadControlBranding();
