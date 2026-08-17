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
  socketConnected: false,
  lastLiveEvent: null,
  lastLoadedAt: null,
};

export function replaceState(next) {
  Object.assign(state, next, { lastLoadedAt: new Date() });
  return state;
}

export function setSocketConnected(value) {
  state.socketConnected = Boolean(value);
  return state.socketConnected;
}

export function setLastLiveEvent(eventName) {
  state.lastLiveEvent = { name: eventName, at: new Date() };
  return state.lastLiveEvent;
}
