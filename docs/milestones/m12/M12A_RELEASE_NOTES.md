# M12-A Release Notes

M12-A begins Milestone 12: Game Setup + Game Management.

Adds:
- `/games` Game Management Home
- existing-game list sourced from `GET /api/games`
- Home/Away Team resolution through existing Team REST APIs
- current authoritative score display
- lifecycle status display
- clock status/display snapshot
- direct Control Center link
- direct Broadcast Overlay link
- responsive phone/tablet/desktop presentation
- explicit handling for Games that do not yet have lifecycle or clock state

Does not add:
- Game creation UI
- Team creation UI
- lifecycle mutation
- clock mutation
- roster mutation
- new database tables
- new Alembic migration
- new Socket.IO contracts
- authentication

M12-A remains a read-only orchestration/navigation layer over existing authoritative APIs.
