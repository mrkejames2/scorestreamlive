# ScoreStreamLive Incident Triage

## First five checks

For a production incident, capture these before changing state:

1. `GET /health/live`
2. `GET /health/ready`
3. `GET /info`
4. The failing response's `X-Request-ID`
5. The affected Game ID when the incident is match-specific

Search application logs by request ID, Game ID, Socket.IO event name, or release.

## Scoreboard / Overlay not updating

```text
/health/live unavailable
    -> application/deployment process problem

/health/live OK, /health/ready unavailable
    -> PostgreSQL/readiness problem

/info release is not expected
    -> deployment/version mismatch

REST authoritative game state is current, Overlay is stale
    -> browser cache / static asset / Socket.IO delivery path

REST authoritative game state is stale
    -> API / PostgreSQL / authoritative-state path

Control access denied
    -> session / role / assignment / tenant authorization path
```

## Browser/cache versus deployment

Compare `/info` release, `X-ScoreStreamLive-Release`, browser-loaded static asset
version query strings, and the current deployed Git commit.

If the server reports the expected release but the browser is executing stale
JavaScript, hard refresh or clear the browser/site cache before changing server
state.

## Socket.IO triage

Search structured logs for:

- `socket.connected`
- `socket.disconnected`
- `socket.subscription.active`
- `socket.subscription.denied`
- `socket.subscription.initial_denied`
- `socket.match_event.blocked`

For match-specific incidents, correlate by Game ID and intended audience:

- public Overlay: `game:<game_id>:public`
- authenticated Control: `game:<game_id>:control`

PostgreSQL remains authoritative. Do not treat Socket.IO transport state as the
source of truth.

## Authentication/authorization triage

If the application is healthy but Control or private APIs are denied:

1. verify login/session validity
2. verify Club role
3. verify TeamManager/GameOperator assignment where applicable
4. verify the resource belongs to the same Club
5. verify direct cross-Club IDs remain denied/masked

Do not relax authorization to resolve a support incident.

## Safe support data

Safe to capture: request ID, Game ID, release, application version/environment,
HTTP status, endpoint path, DB status/latency, and Socket.IO event/audience/room.

Do not capture passwords, session cookies, auth tokens, SMTP password, DB
password, authorization headers, or complete production environment dumps.

## Production recovery principle

Do not create synthetic production games or mutate customer state merely to
diagnose availability. Prefer read-only health, info, diagnostics, and logs.
