# M21-A — Multi-Sport Login & Switch Sport

This archive contains project-root-relative paths. Unzip directly into the repository root. **No `cp` or `mv` steps.**

## Scope
- Existing accounts default to soccer.
- Login without an explicit `next` returns to the last-used sport.
- Safe explicit local deep links continue to work.
- Switch Sport persists the preference in PostgreSQL per authenticated user.
- Soccer `/games` dashboard retains its current game UI, with Switch Sport link.
- Futsal gets a clearly marked landing page; game creation, sport-specific team/game data and futsal clock are **not** implemented in M21-A.

## Important prerequisites
- Apply on a clean, up-to-date repository whose Alembic head is **20261010_0038**.
- This ZIP overwrites `app/models/user.py`, `app/web/auth.py`, and `app/web/games.py`. Back up or commit your work before extracting.
- Review the changes before migration and local testing. This package has not been run against your Docker/Postgres environment.

## Installation from repository root
```bash
unzip -o ScoreStreamLive_M21-A.zip
python3 -m compileall -q app/models/user.py app/web/auth.py app/web/games.py alembic/versions/20261016_0039_m21a_last_used_sport.py
sudo docker compose up --build -d
sudo docker compose exec app alembic upgrade head
sudo docker compose exec app alembic current
```

The container service is named `app` in docker-compose.yml. If your production entrypoint automatically migrates on startup, check that behavior before running `alembic upgrade head` again.

## Manual acceptance
1. Existing account login without `next` opens `/games`.
2. `Switch Sport` opens `/sports`; choose Futsal.
3. Log out and log back in: lands on `/sports/futsal`.
4. Switch back to Soccer, log out/in: lands on `/games`.
5. Login with `?next=/account` still honors the safe deep link.
6. Anonymous POST to `/sports/switch` is denied.
7. Invalid sport value is rejected.
8. Existing soccer game list, create/edit, teams, overlays and sponsors remain operational.

## Rollback
Restore the three overwritten files from the original commit and downgrade the migration to `20261010_0038` (after confirming no subsequent migrations depend on it).

## Notes
The existing `games/index.html` is standalone rather than using a shared base layout. To avoid replacing the large, actively developed game template, M21-A inserts the Switch Sport link into its rendered header. A common navigation component is a recommended future refactor.
