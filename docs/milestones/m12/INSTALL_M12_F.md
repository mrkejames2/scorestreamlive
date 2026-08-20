# M12-F — Game Detail / Launch Hub

## Scope

Adds a dedicated authoritative Game Detail page:

```text
/games/{game_id}
```

The page shows:

- Home vs Away branding
- authoritative score
- lifecycle phase
- clock state
- Home/Away roster counts
- Open Control Center
- Open Broadcast Overlay
- Manage Rosters
- Copy Overlay URL
- Refresh State

M12-E roster management remains at `/games/{game_id}/setup`.

## Install

Extract at the ScoreStreamLive repository root, then:

```bash
cd ~/projects/scorestreamlive

chmod +x apply_m12f.sh scripts/validate_m12f.sh
./apply_m12f.sh
```

The patch script registers the Game Detail route, adds **Open Game** to Game
Management, binds it to `/games/{game_id}`, and adds a **Game Hub** navigation
button to the M12-E roster page.

## Rebuild

```bash
sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.1.196:8000" \
  ./scripts/validate_m12f.sh
```

The validator uses compact output. Successful child-regression details are
suppressed; only milestone summaries and failed checks are shown.
