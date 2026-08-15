# ScoreStreamLive M8-D — Installation

This package completes the **local M8-D implementation**.

It does not mark M8 production-complete. DeepSeek review and Render validation still follow.

## Replace

```text
static/index.html
static/js/socket.js

docs/AI_HANDOFF.md
docs/ARCHITECTURE.md
docs/CURRENT_MILESTONE_STATUS.md
docs/DECISIONS.md
docs/GAMES.md
docs/IMPLEMENTATION_MAP.md
docs/MILESTONES.md
docs/SOCKET_IO.md
```

## New

```text
scripts/validate_m8.sh
docs/CLOCK.md
```

## Do not change

No new M8-D domain/database/service migration is required.

Do not alter:

```text
game_clock model
M8 migration
clock service
clock REST API
Socket.IO server initialization
M7 scoring transaction
Docker / Render architecture
```

unless validation finds an actual defect.

## Copy Rule

Replace matching files completely. Do not append.

## Permissions

```bash
chmod +x scripts/validate_m8.sh
```

## Review

```bash
git status --short
git diff --stat
git diff --check
git diff
```

## Rebuild

```bash
sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
sudo docker compose logs app --tail=150
```

## Local final validation

```bash
sudo BASE_URL="http://192.168.0.153:8000" ./scripts/validate_m8.sh
```

Use your actual VM IP if different.

Local mode performs:

```text
M8-C full checkpoint/regression chain
application restart while a clock is running
post-restart authoritative recovery
post-restart pause
```

## Validation client

Open:

```text
http://<VM-IP>:8000/client
```

Use an existing Game UUID.

Manually observe:

```text
create/get/configure
start/pause/resume/reset
version
server_time
running_since
local count-up/count-down rendering
soccer +N display
clock:updated logs
forced disconnect/reconnect
existing domain event logs
```

## After local PASS

Stop and send the output to GPT.

Then:

```text
DeepSeek review
GPT disposition
Git push
Render deploy
confirm 20260814_0005 migration
production validate_m8.sh
final documentation status flip to M8 COMPLETE
```

## Production final validation

After deployment:

```bash
sudo BASE_URL="https://scorestreamlive.onrender.com" ./scripts/validate_m8.sh
```

Remote mode intentionally does not restart or inspect the local application as proof of the remote deployment. It exercises the remote M8 REST/Socket.IO contract and then runs the production-safe M7 regression.

Confirm the Render deployment logs show the migration at/through:

```text
20260814_0005
```
