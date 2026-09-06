# M17-I Installation

Apply from the ScoreStreamLive repository root on the cumulative
`milestone/m17-i-production-supportability` branch.

```bash
unzip -o SCORESTREAMLIVE_M17-I_IMPLEMENTATION.zip

chmod +x   scripts/validate.sh   scripts/validate_m17i.sh   scripts/regression/production_supportability.sh
```

No `mv` or `cp` step is required. The ZIP contains repository-relative paths
and places every file directly in its resting location.

M17-I adds no Alembic migration.

Rebuild:

```bash
sudo docker compose down
sudo docker compose build app
sudo docker compose up -d
sudo docker compose ps
```

Run M17-I FAST validation:

```bash
sudo BASE_URL="http://localhost:8000" VALIDATION_MODE=local VALIDATION_SCOPE=fast VALIDATION_OUTPUT=full ./scripts/validate_m17i.sh
```

Do not commit the transfer ZIP.
