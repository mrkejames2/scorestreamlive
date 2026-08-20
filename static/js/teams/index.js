const statusEl = document.querySelector("#teams-status");
const listEl = document.querySelector("#teams-list");
const emptyEl = document.querySelector("#teams-empty");
const errorEl = document.querySelector("#teams-error");
const refreshButton = document.querySelector("#refresh-teams");
const template = document.querySelector("#team-card-template");

const summaryTotal = document.querySelector("#summary-total");
const summaryLogos = document.querySelector("#summary-logos");
const summaryBranded = document.querySelector("#summary-branded");

let loadGeneration = 0;

function setStatus(state, text) {
  statusEl.dataset.state = state;
  statusEl.textContent = text;
}

function showError(message) {
  errorEl.textContent = message;
  errorEl.classList.remove("hidden");
}

function clearError() {
  errorEl.textContent = "";
  errorEl.classList.add("hidden");
}

function normalizeColor(value) {
  return typeof value === "string" && /^#[0-9a-fA-F]{6}$/.test(value)
    ? value.toUpperCase()
    : null;
}

function applyColor(swatch, label, value) {
  const normalized = normalizeColor(value);
  if (normalized) {
    swatch.style.background = normalized;
    label.textContent = normalized;
  } else {
    swatch.style.removeProperty("background");
    label.textContent = "Not set";
  }
}

function fallbackLetter(team) {
  const source = (team.short_name || team.name || "T").trim();
  return source ? source.charAt(0).toUpperCase() : "T";
}

async function requestJson(path) {
  const response = await fetch(path, {
    headers: { Accept: "application/json" },
    cache: "no-store",
  });

  if (!response.ok) {
    let detail = "";
    try {
      const body = await response.json();
      detail = body?.detail ? ` — ${body.detail}` : "";
    } catch (_) {
      // Keep the compact HTTP status message.
    }
    throw new Error(`${path} returned HTTP ${response.status}${detail}`);
  }

  return response.json();
}

function renderTeam(team) {
  const node = template.content.cloneNode(true);
  const card = node.querySelector(".team-card");
  const accent = node.querySelector(".team-accent");

  const primary = normalizeColor(team.primary_color);
  const secondary = normalizeColor(team.secondary_color);

  if (primary && secondary) {
    accent.style.background = `linear-gradient(90deg, ${primary} 0 50%, ${secondary} 50% 100%)`;
  } else if (primary) {
    accent.style.background = primary;
  } else if (secondary) {
    accent.style.background = secondary;
  }

  const fallback = node.querySelector(".team-brand-fallback");
  const logo = node.querySelector(".team-brand-logo");
  fallback.textContent = fallbackLetter(team);

  if (team.logo_url) {
    logo.alt = `${team.name || "Team"} logo`;
    logo.src = team.logo_url;
    logo.addEventListener("load", () => {
      logo.classList.remove("hidden");
      fallback.classList.add("hidden");
    });
    logo.addEventListener("error", () => {
      logo.classList.add("hidden");
      fallback.classList.remove("hidden");
    });
  }

  node.querySelector(".team-name").textContent = team.name || "Unnamed Team";
  node.querySelector(".team-short-name").textContent = team.short_name || "NO SHORT NAME";
  node.querySelector(".team-id").textContent = team.id || "—";
  node.querySelector(".team-id").title = team.id || "";

  applyColor(
    node.querySelector(".primary-swatch"),
    node.querySelector(".primary-color"),
    team.primary_color,
  );
  applyColor(
    node.querySelector(".secondary-swatch"),
    node.querySelector(".secondary-color"),
    team.secondary_color,
  );

  card.dataset.teamId = team.id || "";
  listEl.appendChild(node);
}

async function loadTeams() {
  const generation = ++loadGeneration;
  setStatus("loading", "LOADING");
  refreshButton.disabled = true;
  clearError();

  try {
    const teams = await requestJson("/api/teams");
    if (generation !== loadGeneration) return;

    if (!Array.isArray(teams)) {
      throw new Error("Team API returned an unexpected response.");
    }

    listEl.replaceChildren();
    emptyEl.classList.toggle("hidden", teams.length !== 0);

    summaryTotal.textContent = String(teams.length);
    summaryLogos.textContent = String(
      teams.filter((team) => Boolean(team.logo_url)).length,
    );
    summaryBranded.textContent = String(
      teams.filter(
        (team) =>
          Boolean(team.logo_url) ||
          Boolean(normalizeColor(team.primary_color)) ||
          Boolean(normalizeColor(team.secondary_color)),
      ).length,
    );

    teams.forEach(renderTeam);

    setStatus("ready", "READY");
  } catch (error) {
    if (generation !== loadGeneration) return;

    listEl.replaceChildren();
    emptyEl.classList.add("hidden");
    summaryTotal.textContent = "—";
    summaryLogos.textContent = "—";
    summaryBranded.textContent = "—";

    showError(error instanceof Error ? error.message : "Unable to load Teams.");
    setStatus("error", "ERROR");
  } finally {
    if (generation === loadGeneration) {
      refreshButton.disabled = false;
    }
  }
}

refreshButton.addEventListener("click", loadTeams);

loadTeams();
