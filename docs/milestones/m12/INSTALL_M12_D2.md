# M12-D2 — Team Logo Upload + Storage

M12-D2 adds the real Team-logo upload/storage contract.

## Replace

```text
requirements.txt
app/config.py
app/main.py
app/api/teams.py
app/services/team_service.py
Dockerfile
docker-compose.yml
```

## Add

```text
app/api/team_logos.py
app/services/team_logo_storage.py
static/uploads/team-logos/.gitkeep
scripts/validate_m12d2.sh
```

M12-D1 model/schema/migration files remain unchanged.

## API

Upload:

```text
POST /api/teams/{team_id}/logo
multipart field: logo
```

Successful Team responses contain:

```text
logo_url: /api/team-logos/<safe-generated-filename>
```

Retrieval:

```text
GET /api/team-logos/<safe-generated-filename>
```

## Validation Rules

- PNG
- JPEG
- WebP
- 2 MiB default maximum
- image type validated from the file signature
- safe generated server filename
- replacement removes the previous locally-managed file
- non-image -> HTTP 415
- oversize -> HTTP 413
- missing Team -> HTTP 404

## Local persistence

Docker Compose adds:

```text
team_logo_data
```

mounted at:

```text
/home/appuser/app/static/uploads/team-logos
```

This keeps uploaded logos across local app-container rebuilds.

## Production note

The public `logo_url` does not expose the physical storage path. That is
intentional so the storage backend can later move to persistent disk or object
storage without changing Team consumers.

Do not merge M12-D to `main` yet.

## Rebuild

```bash
cd ~/projects/scorestreamlive
chmod +x scripts/validate_m12d2.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

Then:

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m12d2.sh
```
