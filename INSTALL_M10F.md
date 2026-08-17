# ScoreStreamLive M10-F Installation

M10-F adds Connection & Conflict UX. It does not change the database,
migrations, API contracts, scoring transaction, lifecycle service, or clock
service.

## Replace/add these files

```text
templates/control/game.html
static/css/control.css
static/js/control/api.js
static/js/control/clock.js
static/js/control/control.js
static/js/control/socket.js
static/js/control/state.js

scripts/validate_m10a.sh
scripts/validate_m10b.sh
scripts/validate_m10c.sh
scripts/validate_m10d.sh
scripts/validate_m10e.sh
scripts/validate_m10f.sh
scripts/create_m10f_demo.sh
```

## Rebuild

The static files are copied into the Docker image:

```bash
chmod +x scripts/validate_m10*.sh
chmod +x scripts/create_m10f_demo.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m10f.sh
```

Expected final result:

```text
M10-F VALIDATION PASSED
```

The validator chains:

```text
M10-F
  -> M10-E
      -> M10-D
          -> M10-C
              -> M10-B
                  -> M10-A
                      -> M9 regression
```

## Human acceptance fixture

```bash
BASE_URL="http://192.168.12.133:8000" \
  ./scripts/create_m10f_demo.sh
```

Open the printed Control Center URL on two devices.

### M10-F human acceptance

Normal:

```text
[ ] Both devices reach LIVE
[ ] Start First Half on Device A updates Device B
[ ] Goal on Device B updates Device A
```

Disconnect:

```text
[ ] Disable Wi-Fi/network on one controller
[ ] Status changes away from LIVE
[ ] Lifecycle buttons are disabled
[ ] Goal buttons and scorer selectors are disabled
[ ] Existing score/clock remain visible
```

Reconnect:

```text
[ ] Re-enable network
[ ] UI visibly enters RECONNECTING / RECOVERING
[ ] Controls stay disabled during RECOVERING
[ ] Authoritative REST state is recovered
[ ] UI returns to LIVE
[ ] Controls re-enable only after recovery completes
[ ] Score, phase, clock and scoring history match the other device
```

Conflict:

```text
[ ] With both devices on the same valid lifecycle action, tap nearly
    simultaneously
[ ] Only one action commits
[ ] Losing controller does not retry automatically
[ ] Losing controller shows understandable conflict/recovery feedback
[ ] Both controllers converge on the same authoritative state
```

M10-F is complete only when automated validation and this human checkpoint
both pass.
