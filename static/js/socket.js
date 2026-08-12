const logEl = document.getElementById('log');
const gamesLogEl = document.getElementById('games-log');
const gamesListEl = document.getElementById('games-list');

const log = (msg) => {
    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.textContent = '[' + new Date().toLocaleTimeString() + '] ' + msg;
    logEl.prepend(entry);
};

const logGame = (msg) => {
    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.textContent = '[' + new Date().toLocaleTimeString() + '] ' + msg;
    gamesLogEl.prepend(entry);
};

const updateStatus = (state, socketId) => {
    const status = document.getElementById('connection-status');
    status.textContent = state.charAt(0).toUpperCase() + state.slice(1);
    status.className = 'status ' + state;
    document.getElementById('socket-id').textContent = socketId || '-';
};

const renderGameCard = (game) => {
    const div = document.createElement('div');
    div.className = 'game-card';
    div.id = 'game-' + game.id;
    div.innerHTML = '<strong>' + game.name + '</strong> (' + game.status + ')<br><small>' + game.id + '</small>';
    return div;
};

const updateGamesList = (game) => {
    const existing = document.getElementById('game-' + game.id);
    if (existing) {
        existing.replaceWith(renderGameCard(game));
    } else {
        gamesListEl.prepend(renderGameCard(game));
    }
};

// Connect to current application origin with explicit path
const socket = io({
    path: '/socket.io',
    transports: ['websocket', 'polling'],
    reconnection: true,
    reconnectionAttempts: 5,
    reconnectionDelay: 1000,
});

socket.on('connect', () => {
    log('Connected — ' + socket.id);
    updateStatus('connected', socket.id);
});

socket.on('disconnect', (reason) => {
    log('Disconnected — ' + reason);
    updateStatus('disconnected');
});

socket.on('connect_error', (err) => {
    log('Connection error — ' + err.message);
    updateStatus('reconnecting');
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

socket.on('game:created', (data) => {
    logGame('Event: game:created — ' + data.name + ' (' + data.status + ')');
    updateGamesList(data);
});

socket.on('game:updated', (data) => {
    logGame('Event: game:updated — ' + data.name + ' (' + data.status + ')');
    updateGamesList(data);
});

socket.on('error', (err) => {
    log('Socket error — ' + JSON.stringify(err));
});

document.getElementById('btn-ping').addEventListener('click', () => {
    const ts = new Date().toISOString();
    socket.emit('client:ping', { timestamp: ts }, (ack) => {
        log('Ack: client:ping — ' + JSON.stringify(ack));
    });
    log('Sent: client:ping — ' + ts);
});

document.getElementById('btn-broadcast').addEventListener('click', () => {
    socket.emit('test:broadcast', { message: 'Hello from ' + (socket.id || 'unknown') });
    log('Sent: test:broadcast');
});

document.getElementById('btn-disconnect').addEventListener('click', () => {
    socket.disconnect();
    log('Forced disconnect — reconnecting in 2s...');
    setTimeout(() => {
        socket.connect();
    }, 2000);
});