# M12-G — Existing Game Resume / Recovery UX

## Scope

M12-G proves that a Game can be rediscovered and resumed entirely from authoritative server state.

It adds:

- **Resume Game** labeling for active Games on `/games`
- **Review Game** labeling for completed Games
- a visible **Authoritative State Restored** indicator on the Game Hub
- **Resume Control Center** wording for active Games
- an automated recovery test that performs a real application-container restart
- compact validation output with `[step/10]` progress messages

M12-G does not add new score, lifecycle, clock, roster, or Socket.IO domain behavior.

## Install

Extract this package at the repository root, then:

```bash
cd ~/projects/scorestreamlive
chmod +x apply_m12g.sh scripts/validate_m12g.sh
./apply_m12g.sh
```

## Rebuild

```bash
sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.1.196:8000" \
  ./scripts/validate_m12g.sh
```

The validator intentionally restarts the `app` container as part of the recovery proof. PostgreSQL remains running. It then verifies that the same Game, score, lifecycle, running clock, rosters, and scoring history remain authoritative and that `/games`, Game Hub, roster setup, Control Center, and Overlay can all be reopened.

Successful child-regression output is suppressed. Only progress, the final summary, and failures are printed.
