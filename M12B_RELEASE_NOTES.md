# M12-B Release Notes

M12-B adds Game creation to the existing Game Management Home.

Adds:
- New Game creation panel
- Game Name validation
- searchable Home Team selection
- searchable Away Team selection
- team-result cap for large Team collections
- same-team prevention
- Game creation through existing POST /api/games
- success/error feedback
- automatic Game Management refresh after creation

Preserves:
- M12-A recent-25 Game dashboard
- M12-A bounded hydration
- single bulk Team collection fetch
- no per-game Team GET pattern
- existing Control Center links
- existing Broadcast Overlay links
- PostgreSQL/REST authority
- no clock:tick

Does not add:
- Team creation
- lifecycle initialization
- clock initialization
- roster setup
- new database migration
- new Socket.IO contract
