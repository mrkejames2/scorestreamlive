# M12-D1 Installation

M12-D1 adds Team branding persistence and API contract only.

## Replace

```text
app/models/team.py
app/schemas/team.py
app/services/team_service.py
```

## Add

```text
alembic/versions/20260818_0008_add_team_branding.py
scripts/validate_m12d1.sh
```

No change is required to `app/api/teams.py`; its existing Team schemas and Team
service calls automatically expose the new fields.

## Branding fields

```text
logo_url         nullable String(500)
primary_color    nullable String(7), API format #RRGGBB
secondary_color  nullable String(7), API format #RRGGBB
```

M12-D1 deliberately stores only the logo reference. Image upload/storage begins
in M12-D2.

## Build

```bash
cd ~/projects/scorestreamlive
chmod +x scripts/validate_m12d1.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

Verify migration:

```bash
sudo docker compose exec app alembic current
```

Expected head:

```text
20260818_0008 (head)
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m12d1.sh
```

Do not merge to `main`. Commit M12-D1 only to:

```text
milestone/m12-d-team-branding
```
