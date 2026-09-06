import { state } from "./state.js";

const byId = (id) => document.getElementById(id);

function halfLengthLabel() {
  const duration = Number(state.clock?.duration_seconds || 0);
  if (!duration) return "Not configured";
  const phase = state.lifecycle?.phase;
  const halfSeconds = ["second_half", "full_time"].includes(phase)
    ? Math.floor(duration / 2)
    : duration;
  return `${Math.round(halfSeconds / 60)} min`;
}

function playerDisplayName(player) {
  const name = [player?.first_name, player?.last_name].filter(Boolean).join(" ");
  const jersey = player?.jersey_number == null ? "" : `#${player.jersey_number} `;
  return `${jersey}${name || "Unknown Player"}`.trim();
}

function scorerName(event) {
  if (!event?.player_id) return "Unknown scorer";
  const player = [...(state.homeRoster || []), ...(state.awayRoster || [])]
    .find((candidate) => candidate.id === event.player_id);
  return player ? playerDisplayName(player) : "Recorded player";
}

function teamNameForEvent(event) {
  if (event?.team_id === state.homeTeam?.id) return state.homeTeam?.name || "Home";
  if (event?.team_id === state.awayTeam?.id) return state.awayTeam?.name || "Away";
  return "Unknown team";
}

function minuteForEvent(event) {
  const elapsed = Number(event?.game_elapsed_seconds);
  if (!Number.isFinite(elapsed) || elapsed < 0) return "-";
  if (elapsed <= 0) return "1'";
  return `${Math.floor((Math.floor(elapsed) - 1) / 60) + 1}'`;
}

function authoritativeReady() {
  return Boolean(
    state.socketConnected
    && state.stateAuthoritative
    && state.connectionState === "live"
  );
}

function isReadOnly() {
  return Boolean(state.game?.archived_at || state.lifecycle?.phase === "full_time");
}

function setText(id, value) {
  const node = byId(id);
  if (node) node.textContent = value;
}

function renderReadiness() {
  setText("m17f-ready-home", state.homeTeam?.name || "Missing");
  setText("m17f-ready-away", state.awayTeam?.name || "Missing");
  setText("m17f-ready-rosters", `${state.homeRoster?.length || 0} home / ${state.awayRoster?.length || 0} away`);
  setText("m17f-ready-duration", halfLengthLabel());
  setText("m17f-ready-score", `${state.game?.home_score ?? 0}-${state.game?.away_score ?? 0}`);
  setText("m17f-ready-state", authoritativeReady() && state.clock && state.lifecycle ? "READY" : "VERIFYING");

  const banner = byId("m17f-readonly-banner");
  if (!banner) return;
  const archived = Boolean(state.game?.archived_at);
  const fullTime = state.lifecycle?.phase === "full_time";
  banner.classList.toggle("hidden", !(archived || fullTime));
  if (archived) {
    banner.textContent = "ARCHIVED GAME - match-day controls are read-only.";
  } else if (fullTime) {
    banner.textContent = "FULL TIME - match-day controls are read-only. Use the public summary or broadcast scene below.";
  }
}

function lifecycleTargetForPhase() {
  const targets = {
    pregame: "start-first-half-button",
    first_half: "end-first-half-button",
    halftime: "start-second-half-button",
    second_half: "end-game-button",
  };
  return targets[state.lifecycle?.phase] || null;
}

function renderPrimaryAction() {
  const button = byId("m17f-primary-action");
  const note = byId("m17f-primary-note");
  if (!button || !note) return;
  delete button.dataset.proxyTarget;

  if (isReadOnly()) {
    button.disabled = true;
    button.textContent = state.game?.archived_at ? "Archived Game" : "Game Complete";
    note.textContent = "No match-day mutation is available.";
    return;
  }
  if (!authoritativeReady()) {
    button.disabled = true;
    button.textContent = "Waiting for Live State";
    note.textContent = "Controls remain paused until authoritative state is confirmed.";
    return;
  }

  const phase = state.lifecycle?.phase || "pregame";
  if (["first_half", "second_half"].includes(phase) && ["running", "paused"].includes(state.clock?.status)) {
    const target = byId("clock-pause-resume-button");
    button.disabled = Boolean(target?.disabled);
    button.textContent = state.clock?.status === "paused" ? "Resume Clock" : "Pause Clock";
    note.textContent = state.clock?.status === "paused"
      ? "Primary action: resume match time when play restarts."
      : "Primary action: pause match time for a stoppage.";
    button.dataset.proxyTarget = "clock-pause-resume-button";
    return;
  }

  const targetId = lifecycleTargetForPhase();
  const target = targetId ? byId(targetId) : null;
  if (target) {
    button.disabled = Boolean(target.disabled);
    button.textContent = target.textContent;
    note.textContent = "Primary action follows the current authoritative match phase.";
    button.dataset.proxyTarget = target.id;
    return;
  }

  button.disabled = true;
  button.textContent = "No Action Available";
  note.textContent = "Refresh authoritative state if this is unexpected.";
}

function renderActivity() {
  const container = byId("m17f-recent-activity");
  if (!container) return;
  container.replaceChildren();
  const events = [...(state.scoringEvents || [])].reverse().slice(0, 6);

  if (!events.length) {
    const empty = document.createElement("div");
    empty.className = "m17f-empty";
    empty.textContent = "No scoring activity yet.";
    container.appendChild(empty);
  } else {
    for (const event of events) {
      const row = document.createElement("div");
      row.className = "m17f-activity-row";
      const minute = document.createElement("span");
      minute.className = "m17f-activity-minute";
      minute.textContent = minuteForEvent(event);
      const detail = document.createElement("span");
      detail.className = "m17f-activity-detail";
      detail.textContent = `GOAL - ${teamNameForEvent(event)} - ${scorerName(event)}`;
      row.append(minute, detail);
      container.appendChild(row);
    }
  }

  setText("m17f-activity-phase", String(state.lifecycle?.phase || "pregame").replaceAll("_", " ").toUpperCase());
}

function renderPostgame() {
  const section = byId("m17f-postgame-actions");
  if (!section) return;
  const final = state.lifecycle?.phase === "full_time";
  section.classList.toggle("hidden", !final);
  if (!final) return;

  const gameId = document.body.dataset.gameId;
  const summary = byId("m17f-summary-link");
  const broadcast = byId("m17f-broadcast-link");
  if (summary) summary.href = `/summary/games/${gameId}`;
  if (broadcast) broadcast.href = `/broadcast/games/${gameId}`;
  setText("m17f-final-score", `${state.homeTeam?.name || "Home"} ${state.game?.home_score ?? 0} - ${state.game?.away_score ?? 0} ${state.awayTeam?.name || "Away"}`);
}

function enforceReadOnlyControls() {
  if (!isReadOnly()) return;
  const ids = [
    "start-first-half-button", "end-first-half-button", "start-second-half-button", "end-game-button",
    "clock-pause-resume-button", "clock-duration-save", "home-goal-button", "away-goal-button",
    "home-scorer-select", "away-scorer-select", "broadcast-message-save", "broadcast-message-weather",
    "broadcast-message-clear", "broadcast-message-input",
  ];
  for (const id of ids) {
    const node = byId(id);
    if (node) node.disabled = true;
  }
  document.querySelectorAll('input[name="clock-duration-minutes"]').forEach((node) => { node.disabled = true; });
}

function render() {
  renderReadiness();
  renderPrimaryAction();
  renderActivity();
  renderPostgame();
  enforceReadOnlyControls();
}

function installPrimaryActionProxy() {
  const button = byId("m17f-primary-action");
  if (!button) return;
  button.addEventListener("click", () => {
    if (button.disabled) return;
    const targetId = button.dataset.proxyTarget;
    const target = targetId ? byId(targetId) : null;
    if (target && !target.disabled) target.click();
  });
}

function start() {
  installPrimaryActionProxy();
  render();
  window.setInterval(render, 400);
  document.addEventListener("visibilitychange", () => { if (!document.hidden) render(); });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", start, { once: true });
} else {
  start();
}
