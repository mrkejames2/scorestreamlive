const JSON_HEADERS = { Accept: "application/json" };

async function requestJson(path, { method = "GET", payload = undefined } = {}) {
  const options = { method, headers: { ...JSON_HEADERS }, cache: "no-store" };

  if (payload !== undefined) {
    options.headers["Content-Type"] = "application/json";
    options.body = JSON.stringify(payload);
  }

  const response = await fetch(path, options);
  let body = null;

  try {
    body = await response.json();
  } catch (_) {
    body = null;
  }

  if (!response.ok) {
    const error = new Error(
      body?.detail
        ? `${response.status} — ${JSON.stringify(body.detail)}`
        : `${response.status} ${response.statusText}`,
    );
    error.status = response.status;
    error.body = body;
    throw error;
  }

  return body;
}

export function getGame(gameId) {
  return requestJson(`/api/games/${encodeURIComponent(gameId)}`);
}

export function getTeam(teamId) {
  return requestJson(`/api/teams/${encodeURIComponent(teamId)}`);
}

export function getRoster(teamId) {
  return requestJson(`/api/teams/${encodeURIComponent(teamId)}/players`);
}

export function getLifecycle(gameId) {
  return requestJson(`/api/games/${encodeURIComponent(gameId)}/lifecycle`);
}

export function getClock(gameId) {
  return requestJson(`/api/games/${encodeURIComponent(gameId)}/clock`);
}

export function getScoringEvents(gameId) {
  return requestJson(`/api/games/${encodeURIComponent(gameId)}/scoring-events`);
}

export function transitionLifecycle(
  gameId,
  { action, expectedLifecycleVersion, expectedClockVersion },
) {
  return requestJson(
    `/api/games/${encodeURIComponent(gameId)}/lifecycle/transition`,
    {
      method: "POST",
      payload: {
        action,
        expected_lifecycle_version: expectedLifecycleVersion,
        expected_clock_version: expectedClockVersion,
      },
    },
  );
}


export function createScoringEvent(gameId, teamId, playerId = null) {
  return requestJson(`/api/scoring-events`, {
    method: "POST",
    payload: {
      game_id: gameId,
      team_id: teamId,
      player_id: playerId || null,
      event_type: "goal",
    },
  });
}
