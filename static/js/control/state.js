export const state = {
  gameId: null,
  game: null,
  homeTeam: null,
  awayTeam: null,
  homeRoster: [],
  awayRoster: [],
  lifecycle: null,
  clock: null,
  scoringEvents: [],

  // M10-F:
  // socketConnected means the browser is safe to mutate, not merely that
  // Engine.IO transport happens to be connected.
  socketConnected: false,
  connectionState: "connecting",
  stateAuthoritative: false,

  lastLiveEvent: null,
  lastLoadedAt: null,
};

export function replaceState(next) {
  Object.assign(state, next, {
    lastLoadedAt: new Date(),
    stateAuthoritative: true,
  });
  return state;
}

export function setSocketConnected(value) {
  state.socketConnected = Boolean(value);
  return state.socketConnected;
}

export function setConnectionState(value) {
  state.connectionState = value;
  return state.connectionState;
}

export function setStateAuthoritative(value) {
  state.stateAuthoritative = Boolean(value);
  return state.stateAuthoritative;
}

export function setLastLiveEvent(eventName) {
  state.lastLiveEvent = { name: eventName, at: new Date() };
  return state.lastLiveEvent;
}
