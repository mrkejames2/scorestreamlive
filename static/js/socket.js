const socket = io({
  path: '/socket.io',
  transports: ['websocket', 'polling'],
  reconnection: true,
  reconnectionAttempts: 5,
  reconnectionDelay: 1000,
});

let lifecycleState = null;
let clockState = null;
let serverOffsetMs = 0;

const el = (id) => document.getElementById(id);

const log = (target, message) => {
  const row = document.createElement('div');
  row.className = 'entry';
  row.textContent = '[' + new Date().toLocaleTimeString() + '] ' + message;
  target.prepend(row);
};

const gameId = () => el('game-id').value.trim();

socket.on('connect', () => {
  el('connection-status').textContent = 'Connected';
  el('connection-status').className = 'status connected';
  el('socket-id').textContent = socket.id;
});

socket.on('disconnect', () => {
  el('connection-status').textContent = 'Disconnected';
  el('connection-status').className = 'status disconnected';
  el('socket-id').textContent = '-';
});

socket.on('game:phase_updated', (data) => {
  log(el('lifecycle-log'), 'game:phase_updated ' + JSON.stringify(data));
  const selected = gameId();
  if (selected && data.game_id !== selected) return;

  const current = lifecycleState ? Number(lifecycleState.version || 0) : 0;
  const incoming = Number(data.version || 0);
  if (incoming < current) return;

  lifecycleState = data;
  el('transition-id').textContent = data.transition_id || '-';
  renderLifecycle();
});

socket.on('clock:updated', (data) => {
  log(el('clock-log'), 'clock:updated ' + JSON.stringify(data));
  const selected = gameId();
  if (selected && data.game_id !== selected) return;

  const current = clockState ? Number(clockState.version || 0) : 0;
  const incoming = Number(data.version || 0);
  if (incoming < current) return;

  clockState = data;
  if (data.transition_id) el('transition-id').textContent = data.transition_id;
  updateServerOffset(data);
  renderClock();
});

[
  'team:created','team:updated',
  'game:created','game:updated','game:score_updated',
  'player:created','player:updated','roster:updated',
  'scoring_event:created'
].forEach((name) => {
  socket.on(name, (data) => log(el('domain-log'), name + ' ' + JSON.stringify(data)));
});

socket.on('server:pong', (data) => {
  log(el('domain-log'), 'server:pong ' + JSON.stringify(data));
});

const parseMs = (value) => {
  if (!value) return null;
  const ms = Date.parse(value);
  return Number.isFinite(ms) ? ms : null;
};

const updateServerOffset = (state) => {
  const serverMs = parseMs(state.server_time);
  serverOffsetMs = serverMs === null ? 0 : serverMs - Date.now();
};

const estimatedServerNow = () => Date.now() + serverOffsetMs;

const authoritativeElapsed = () => {
  if (!clockState) return 0;

  let elapsed = Number(clockState.elapsed_seconds || 0);
  if (clockState.status === 'running' && clockState.running_since) {
    const since = parseMs(clockState.running_since);
    if (since !== null) {
      elapsed += Math.max(
        Math.floor((estimatedServerNow() - since) / 1000),
        0
      );
    }
  }
  return Math.max(elapsed, 0);
};

const displaySeconds = () => {
  if (!clockState) return 0;
  const elapsed = authoritativeElapsed();
  if (clockState.mode === 'count_down') {
    return Math.max(Number(clockState.duration_seconds) - elapsed, 0);
  }
  return elapsed;
};

const addedTime = () => {
  if (!clockState || clockState.mode !== 'count_up') return null;
  const elapsed = authoritativeElapsed();
  const duration = Number(clockState.duration_seconds);
  if (elapsed < duration) return null;
  return Math.floor((elapsed - duration) / 60) + 1;
};

const fmt = (seconds) => {
  const s = Math.max(Math.floor(Number(seconds) || 0), 0);
  return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
};

const renderLifecycle = () => {
  el('phase').textContent = lifecycleState?.phase || '-';
  el('lifecycle-version').textContent = lifecycleState?.version ?? '-';
};

const renderClock = () => {
  el('clock-status').textContent = clockState?.status || '-';
  el('clock-version').textContent = clockState?.version ?? '-';
  el('clock-mode').textContent = clockState?.mode || '-';
  el('clock-duration').textContent = clockState ? clockState.duration_seconds + ' sec' : '-';
  el('running-since').textContent = clockState?.running_since || '-';
  el('clock-display').textContent = clockState ? fmt(displaySeconds()) : '--:--';

  const plus = addedTime();
  el('added-time').textContent = plus === null ? '' : ' +' + plus;
};

const api = async (method, path, payload) => {
  const options = {method, headers: {'Content-Type': 'application/json'}};
  if (payload !== undefined) options.body = JSON.stringify(payload);

  const response = await fetch(path, options);
  let body = null;
  try { body = await response.json(); } catch (_) {}

  if (!response.ok) {
    throw new Error(response.status + ' ' + JSON.stringify(body));
  }
  return body;
};

const refresh = async () => {
  const id = gameId();
  if (!id) throw new Error('Game ID required');

  lifecycleState = await api('GET', '/api/games/' + id + '/lifecycle');
  clockState = await api('GET', '/api/games/' + id + '/clock');
  updateServerOffset(clockState);
  renderLifecycle();
  renderClock();
};

el('btn-refresh').addEventListener('click', () => {
  refresh().catch((e) => log(el('domain-log'), 'Refresh ERROR ' + e.message));
});

el('btn-create-lifecycle').addEventListener('click', async () => {
  try {
    const id = gameId();
    lifecycleState = await api('POST', '/api/games/' + id + '/lifecycle', {});
    renderLifecycle();
  } catch (e) {
    log(el('lifecycle-log'), 'Create lifecycle ERROR ' + e.message);
  }
});

el('btn-create-clock').addEventListener('click', async () => {
  try {
    const id = gameId();
    clockState = await api('POST', '/api/games/' + id + '/clock', {
      mode: 'count_up',
      duration_seconds: 2700,
    });
    updateServerOffset(clockState);
    renderClock();
  } catch (e) {
    log(el('clock-log'), 'Create clock ERROR ' + e.message);
  }
});

document.querySelectorAll('[data-action]').forEach((button) => {
  button.addEventListener('click', async () => {
    try {
      if (!lifecycleState || !clockState) {
        await refresh();
      }

      const response = await api(
        'POST',
        '/api/games/' + gameId() + '/lifecycle/transition',
        {
          action: button.dataset.action,
          expected_lifecycle_version: Number(lifecycleState.version),
          expected_clock_version: Number(clockState.version),
        }
      );

      lifecycleState = response.lifecycle;
      clockState = response.clock;
      el('transition-id').textContent = response.transition_id || '-';
      updateServerOffset(clockState);
      renderLifecycle();
      renderClock();
    } catch (e) {
      log(el('lifecycle-log'), button.dataset.action + ' ERROR ' + e.message);
    }
  });
});

el('btn-ping').addEventListener('click', () => {
  socket.emit('client:ping', {source: 'm9-client'});
});

el('btn-reconnect').addEventListener('click', () => {
  socket.disconnect();
  setTimeout(() => socket.connect(), 1500);
});

setInterval(renderClock, 250);
