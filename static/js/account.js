const $ = id => document.getElementById(id);

async function req(path, opt = {}) {
  const response = await fetch(path, {
    headers: {"Content-Type": "application/json", ...(opt.headers || {})},
    ...opt
  });
  if (!response.ok) {
    let detail = {};
    try { detail = await response.json(); } catch {}
    throw new Error(detail.detail || `${response.status}`);
  }
  return response.status === 204 ? null : response.json();
}

let members = [];
let teams = [];
let games = [];
let asgn = {team_managers: [], game_operators: []};
let editingMemberId = null;

function clear(node) {
  while (node?.firstChild) node.removeChild(node.firstChild);
}

function option(value, text) {
  const node = document.createElement("option");
  node.value = value;
  node.textContent = text;
  return node;
}

function actionRow(text, fn) {
  const row = document.createElement("div");
  row.className = "item";
  const label = document.createElement("span");
  label.textContent = text;
  const button = document.createElement("button");
  button.type = "button";
  button.className = "remove";
  button.textContent = "Remove";
  button.onclick = fn;
  row.append(label, button);
  return row;
}

function statusBadge(member) {
  const badge = document.createElement("span");
  badge.className = `member-status ${member.is_active ? "active" : "inactive"}`;
  badge.textContent = member.is_active ? "ACTIVE" : "INACTIVE";
  return badge;
}

function memberAssignments(memberId) {
  return {
    teams: asgn.team_managers.filter(item => item.user_id === memberId),
    games: asgn.game_operators.filter(item => item.user_id === memberId)
  };
}

function describeAssignments(memberId) {
  const current = memberAssignments(memberId);
  const lines = [];
  if (current.teams.length) {
    lines.push(`Teams: ${current.teams.map(item => item.team_name).join(", ")}`);
  }
  if (current.games.length) {
    lines.push(`Games: ${current.games.map(item => item.game_name).join(", ")}`);
  }
  return lines.length ? lines.join(" • ") : "No explicit resource assignments.";
}

async function load() {
  if (document.body.dataset.role !== "DIRECTOR") return;
  [members, teams, games, asgn] = await Promise.all([
    req("/api/admin/members"),
    req("/api/teams"),
    req("/api/games"),
    req("/api/admin/assignments")
  ]);
  render();
}

function renderMembers() {
  const container = $("members");
  clear(container);

  members.forEach(member => {
    const row = document.createElement("div");
    row.className = "item member-row";

    const copy = document.createElement("div");
    copy.className = "member-copy";
    const name = document.createElement("strong");
    name.textContent = member.display_name || member.email;
    const details = document.createElement("div");
    details.className = "muted";
    details.textContent = `${member.email} · ${member.club_role}`;
    const assignmentCopy = document.createElement("div");
    assignmentCopy.className = "muted member-assignments";
    assignmentCopy.textContent = describeAssignments(member.id);
    copy.append(name, details, assignmentCopy);

    const actions = document.createElement("div");
    actions.className = "member-actions";
    actions.append(statusBadge(member));
    const manage = document.createElement("button");
    manage.type = "button";
    manage.className = "button button-secondary button-compact";
    manage.textContent = "Manage";
    manage.onclick = () => openEditor(member.id);
    actions.append(manage);

    row.append(copy, actions);
    container.append(row);
  });
}

function renderSelectors() {
  for (const [id, role] of [["manager-select", "MANAGER"], ["operator-select", "OPERATOR"]]) {
    const select = $(id);
    clear(select);
    members
      .filter(member => member.club_role === role && member.is_active)
      .forEach(member => select.append(option(member.id, member.display_name || member.email)));
  }

  const teamSelect = $("team-select");
  clear(teamSelect);
  teams.forEach(team => teamSelect.append(option(team.id, team.name)));

  const gameSelect = $("game-select");
  clear(gameSelect);
  games.forEach(game => gameSelect.append(option(game.id, game.name)));
}

function renderAssignments() {
  const teamAssignments = $("team-assignments");
  clear(teamAssignments);
  asgn.team_managers.forEach(item => teamAssignments.append(
    actionRow(`${item.team_name} → ${item.user_name}`, async () => {
      await req(`/api/admin/teams/${item.team_id}/managers/${item.user_id}`, {method: "DELETE"});
      await load();
    })
  ));

  const gameAssignments = $("game-assignments");
  clear(gameAssignments);
  asgn.game_operators.forEach(item => gameAssignments.append(
    actionRow(`${item.game_name} → ${item.user_name}`, async () => {
      await req(`/api/admin/games/${item.game_id}/operators/${item.user_id}`, {method: "DELETE"});
      await load();
    })
  ));
}

function render() {
  renderMembers();
  renderSelectors();
  renderAssignments();

  if (editingMemberId) {
    const stillExists = members.some(member => member.id === editingMemberId);
    if (stillExists) openEditor(editingMemberId, false);
    else closeEditor();
  }
}

function openEditor(memberId, focus = true) {
  const member = members.find(item => item.id === memberId);
  if (!member) return;

  editingMemberId = memberId;
  $("editor-name").textContent = member.display_name || member.email;
  $("editor-email").textContent = member.email;
  $("editor-role").value = member.club_role;
  $("editor-active").value = String(member.is_active);
  $("editor-assignments").textContent = describeAssignments(member.id);
  $("editor-warning").textContent = "";
  $("editor-message").textContent = "";
  $("member-editor").hidden = false;

  if (focus) $("editor-role").focus();
}

function closeEditor() {
  editingMemberId = null;
  $("member-editor").hidden = true;
  $("editor-message").textContent = "";
}

function confirmationMessage(member, nextRole, nextActive) {
  const messages = [];
  const current = memberAssignments(member.id);

  if (member.club_role !== nextRole) {
    if (nextRole === "DIRECTOR") {
      messages.push("This grants full Club administration access.");
    } else if (member.club_role === "DIRECTOR") {
      messages.push("This removes full Club administration access.");
    }

    if (nextRole === "MANAGER" && current.games.length) {
      messages.push(`This removes ${current.games.length} Game Operator assignment(s).`);
    }
    if (nextRole === "OPERATOR" && current.teams.length) {
      messages.push(`This removes ${current.teams.length} Team Manager assignment(s).`);
    }
    if (nextRole === "DIRECTOR" && (current.teams.length || current.games.length)) {
      messages.push("Directors receive Club-wide access, so explicit Team/Game assignments will be removed.");
    }
  }

  if (member.is_active && !nextActive) {
    messages.push("Deactivating this user immediately revokes authenticated sessions.");
  }

  return messages.join("\n");
}

$("member-edit-form")?.addEventListener("submit", async event => {
  event.preventDefault();
  const member = members.find(item => item.id === editingMemberId);
  if (!member) return;

  const nextRole = $("editor-role").value;
  const nextActive = $("editor-active").value === "true";
  const warning = confirmationMessage(member, nextRole, nextActive);

  $("editor-warning").textContent = warning;
  $("editor-message").textContent = "";

  if (warning && !window.confirm(`${warning}\n\nContinue?`)) return;

  try {
    const updated = await req(`/api/admin/members/${member.id}`, {
      method: "PATCH",
      body: JSON.stringify({role: nextRole, is_active: nextActive})
    });

    const currentUserId = document.body.dataset.userId;
    if (member.id === currentUserId) {
      if (!updated.is_active) {
        window.location.assign("/login");
        return;
      }
      if (updated.club_role !== "DIRECTOR") {
        window.location.assign("/account");
        return;
      }
    }

    await load();
    $("editor-message").textContent = "Member updated.";
  } catch (error) {
    $("editor-message").textContent = error.message;
  }
});

$("editor-close")?.addEventListener("click", closeEditor);

$("member-form")?.addEventListener("submit", async event => {
  event.preventDefault();
  $("member-message").textContent = "";
  try {
    await req("/api/admin/members", {
      method: "POST",
      body: JSON.stringify({
        display_name: $("member-name").value,
        email: $("member-email").value,
        role: $("member-role").value,
        temporary_password: $("member-password").value
      })
    });
    event.target.reset();
    await load();
  } catch (error) {
    $("member-message").textContent = error.message;
  }
});

$("team-form")?.addEventListener("submit", async event => {
  event.preventDefault();
  if (!$("manager-select").value || !$("team-select").value) return;
  await req(`/api/admin/teams/${$("team-select").value}/managers`, {
    method: "POST",
    body: JSON.stringify({user_id: $("manager-select").value})
  });
  await load();
});

$("game-form")?.addEventListener("submit", async event => {
  event.preventDefault();
  if (!$("operator-select").value || !$("game-select").value) return;
  await req(`/api/admin/games/${$("game-select").value}/operators`, {
    method: "POST",
    body: JSON.stringify({user_id: $("operator-select").value})
  });
  await load();
});

load().catch(error => console.error("M17-A account load", error));
