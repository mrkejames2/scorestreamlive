const logEl = document.getElementById('log');
const domainLogEl = document.getElementById('domain-log');
const clockLogEl = document.getElementById('clock-log');

let clockState = null;
let renderTimer = null;
let serverOffsetMs = 0;

const writeLog = (element, message) => {
    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.textContent = '[' + new Date().toLocaleTimeString() + '] ' + message;
    element.prepend(entry);
};

const log = (message) => writeLog(logEl, message);
const logDomain = (message) => writeLog(domainLogEl, message);
const logClock = (message) => writeLog(clockLogEl, message);

const updateStatus = (state, socketId) => {
    const status = document.getElementById('connection-status');
    status.textContent = state.charAt(0).toUpperCase() + state.slice(1);
    status.className = 'status ' + state;
    document.getElementById('socket-id').textContent = socketId || '-';
};

const socket = io({
    path: '/socket.io',
    transports: ['websocket', 'polling'],
    reconnection: true,
    reconnectionAttempts: 5,
    reconnectionDelay: 1000,
});

socket.on('connect', () => {
    updateStatus('connected', socket.id);
    log('Connected — ' + socket.id);
});

socket.on('disconnect', (reason) => {
    updateStatus('disconnected');
    log('Disconnected — ' + reason);
});

socket.on('connect_error', (error) => {
    updateStatus('reconnecting');
    log('Connection error — ' + error.message);
});

socket.on('connection:ready', (data) => {
    log('Event: connection:ready — ' + JSON.stringify(data));
});

socket.on('server:pong', (data) => {
    log('Event: server:pong — ' + JSON.stringify(data));
});

socket.on('test:broadcast', (data) => {
    log('Event: test:broadcast — ' + JSON.stringify(data));
});

[
    'team:created',
    'team:updated',
    'game:created',
    'game:updated',
    'player:created',
    'player:updated',
    'roster:updated',
    'scoring_event:created',
    'game:score_updated',
].forEach((eventName) => {
    socket.on(eventName, (data) => {
        logDomain('Event: ' + eventName + ' — ' + JSON.stringify(data));
    });
});

const parseTimestamp = (value) => {
    if (!value) return null;
    const ms = Date.parse(value);
    return Number.isFinite(ms) ? ms : null;
};

const calculateServerOffset = (state) => {
    const serverMs = parseTimestamp(state.server_time);
    if (serverMs === null) {
        serverOffsetMs = 0;
        return;
    }

    // Simple one-way estimate for diagnostic display.
    serverOffsetMs = serverMs - Date.now();
};

const estimatedServerNowMs = () => Date.now() + serverOffsetMs;

const calculateAuthoritativeElapsed = (state) => {
    if (!state) return 0;

    let elapsed = Number(state.elapsed_seconds || 0);

    if (state.status === 'running' && state.running_since) {
        const runningSinceMs = parseTimestamp(state.running_since);

        if (runningSinceMs !== null) {
            const delta = Math.floor(
                (estimatedServerNowMs() - runningSinceMs) / 1000
            );
            elapsed += Math.max(delta, 0);
        }
    }

    return Math.max(elapsed, 0);
};

const calculateDisplaySeconds = (state, authoritativeElapsed) => {
    if (!state) return 0;

    if (state.mode === 'count_down') {
        return Math.max(
            Number(state.duration_seconds) - authoritativeElapsed,
            0
        );
    }

    return authoritativeElapsed;
};

const calculateSoccerAddedTime = (state, authoritativeElapsed) => {
    if (
        !state ||
        state.mode !== 'count_up' ||
        authoritativeElapsed < Number(state.duration_seconds)
    ) {
        return null;
    }

    return Math.floor(
        (authoritativeElapsed - Number(state.duration_seconds)) / 60
    ) + 1;
};

const formatSeconds = (seconds) => {
    const safeSeconds = Math.max(Math.floor(Number(seconds) || 0), 0);
    const minutes = Math.floor(safeSeconds / 60);
    const secs = safeSeconds % 60;
    return String(minutes) + ':' + String(secs).padStart(2, '0');
};

const renderClock = () => {
    if (!clockState) {
        document.getElementById('clock-display').textContent = '--:--';
        document.getElementById('added-time').textContent = '';
        return;
    }

    const authoritative = calculateAuthoritativeElapsed(clockState);
    const display = calculateDisplaySeconds(clockState, authoritative);
    const added = calculateSoccerAddedTime(clockState, authoritative);

    document.getElementById('clock-display').textContent = formatSeconds(display);
    document.getElementById('added-time').textContent =
        added === null ? '' : '+' + added;

    document.getElementById('clock-status').textContent = clockState.status;
    document.getElementById('clock-version').textContent = clockState.version;
    document.getElementById('clock-current-mode').textContent = clockState.mode;
    document.getElementById('clock-current-duration').textContent =
        clockState.duration_seconds + ' sec';
    document.getElementById('clock-elapsed').textContent =
        clockState.elapsed_seconds + ' sec';
    document.getElementById('clock-authoritative').textContent =
        authoritative + ' sec';
    document.getElementById('clock-running-since').textContent =
        clockState.running_since || '-';
    document.getElementById('clock-server-time').textContent =
        clockState.server_time || '-';
};

const applyClockState = (incoming, source) => {
    const incomingVersion = Number(incoming.version || 0);
    const currentVersion = clockState ? Number(clockState.version || 0) : 0;

    if (clockState && incoming.game_id !== clockState.game_id) {
        const selectedGame = document.getElementById('clock-game-id').value.trim();

        if (selectedGame && incoming.game_id !== selectedGame) {
            logClock(
                'Ignored ' + source + ' for other Game ' + incoming.game_id
            );
            return;
        }
    }

    if (clockState && incomingVersion < currentVersion) {
        logClock(
            'Ignored stale ' + source +
            ' version ' + incomingVersion +
            ' < local ' + currentVersion
        );
        return;
    }

    clockState = incoming;
    calculateServerOffset(incoming);

    document.getElementById('clock-game-id').value = incoming.game_id;
    document.getElementById('clock-mode').value = incoming.mode;
    document.getElementById('clock-duration').value = incoming.duration_seconds;

    logClock(
        source +
        ' — game=' + incoming.game_id +
        ' version=' + incoming.version +
        ' status=' + incoming.status +
        ' mode=' + incoming.mode
    );

    renderClock();
};

socket.on('clock:updated', (data) => {
    applyClockState(data, 'Socket.IO clock:updated');
});

// A clock:tick handler is intentionally diagnostic-only.
// M8 architecture must never produce this event.
socket.on('clock:tick', (data) => {
    logClock(
        'ERROR: unexpected clock:tick received — ' + JSON.stringify(data)
    );
});

const gameId = () =>
    document.getElementById('clock-game-id').value.trim();

const expectedVersion = () => {
    if (!clockState) {
        throw new Error('Load/create the clock first so version is known');
    }
    return Number(clockState.version);
};

const api = async (method, path, payload) => {
    const options = {
        method,
        headers: {
            'Content-Type': 'application/json',
        },
    };

    if (payload !== undefined) {
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
        const detail = body && body.detail
            ? JSON.stringify(body.detail)
            : response.statusText;
        throw new Error(
            method + ' ' + path + ' → ' +
            response.status + ' ' + detail
        );
    }

    return body;
};

const runClockAction = async (label, action) => {
    try {
        const state = await action();
        if (state) {
            applyClockState(state, 'REST ' + label);
        }
    } catch (error) {
        logClock('REST ' + label + ' ERROR — ' + error.message);
    }
};

document.getElementById('btn-clock-create').addEventListener('click', () => {
    runClockAction('create', async () => {
        const id = gameId();
        if (!id) throw new Error('Game ID is required');

        return api(
            'POST',
            '/api/games/' + id + '/clock',
            {
                mode: document.getElementById('clock-mode').value,
                duration_seconds: Number(
                    document.getElementById('clock-duration').value
                ),
            }
        );
    });
});

document.getElementById('btn-clock-get').addEventListener('click', () => {
    runClockAction('get', async () => {
        const id = gameId();
        if (!id) throw new Error('Game ID is required');
        return api('GET', '/api/games/' + id + '/clock');
    });
});

document.getElementById('btn-clock-configure').addEventListener('click', () => {
    runClockAction('configure', async () => {
        const id = gameId();
        return api(
            'PATCH',
            '/api/games/' + id + '/clock',
            {
                expected_version: expectedVersion(),
                mode: document.getElementById('clock-mode').value,
                duration_seconds: Number(
                    document.getElementById('clock-duration').value
                ),
            }
        );
    });
});

[
    ['start', 'btn-clock-start'],
    ['pause', 'btn-clock-pause'],
    ['resume', 'btn-clock-resume'],
    ['reset', 'btn-clock-reset'],
].forEach(([command, buttonId]) => {
    document.getElementById(buttonId).addEventListener('click', () => {
        runClockAction(command, async () => {
            const id = gameId();
            return api(
                'POST',
                '/api/games/' + id + '/clock/' + command,
                { expected_version: expectedVersion() }
            );
        });
    });
});

document.getElementById('btn-ping').addEventListener('click', () => {
    const timestamp = new Date().toISOString();

    socket.emit(
        'client:ping',
        { timestamp },
        (ack) => log('Ack: client:ping — ' + JSON.stringify(ack))
    );

    log('Sent: client:ping — ' + timestamp);
});

document.getElementById('btn-broadcast').addEventListener('click', () => {
    socket.emit(
        'test:broadcast',
        { message: 'Hello from ' + (socket.id || 'unknown') }
    );
    log('Sent: test:broadcast');
});

document.getElementById('btn-disconnect').addEventListener('click', () => {
    socket.disconnect();
    log('Forced disconnect — reconnecting in 2 seconds');

    setTimeout(() => {
        socket.connect();
    }, 2000);
});

renderTimer = setInterval(renderClock, 250);
renderClock();
