# M12-E — Roster Management for Setup

## Scope

M12-E adds a dedicated setup page:

```text
/games/{game_id}/setup
```

It supports authoritative Home/Away roster review, Team branding, first/last name,
optional jersey number, Player creation through the existing Player API, immediate
authoritative roster refresh after creation, and a Manage Roster action from Game
Management.

No lineup, substitution, position, card, import, delete, or edit workflow is added.

## Install

Extract this ZIP at the ScoreStreamLive repository root, then run:

```bash
cd ~/projects/scorestreamlive

chmod +x apply_m12e.sh scripts/validate_m12e.sh
./apply_m12e.sh
```

The patch script is idempotent. It registers the web route, adds Manage Roster to
Game Management cards, and binds the setup URL to the Game ID.

## Rebuild

```bash
sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m12e.sh
```

The validator runs M12-E checks and then the full M12-D6 cumulative regression.
