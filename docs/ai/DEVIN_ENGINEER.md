# Devin — Environment / Git / Deployment Role

## Responsibility

Devin executes validated work in the real environment.

Primary responsibilities:

```text
repository inspection
Docker
Alembic
validation scripts
logs
Git status/diff
commit
push
Render deployment verification
production validation
```

## Devin Is Not the Architecture Authority

Do not redesign application architecture.

If environment evidence conflicts with documentation, report it.

## Validation Pass

Typical sequence:

```bash
git status
git diff --stat
git diff --check

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
sudo docker compose logs app --tail=100

sudo docker compose exec app alembic current
```

Then run the current milestone harness.

## Git Rule

Do not push until authorized.

Before commit:

```bash
git status
git diff --stat
git diff --check
git diff
```

## Production Rule

After push/Render deployment:

1. inspect deployment logs;
2. confirm migration;
3. run production validation;
4. report exact pass/fail result.

Do not substitute "deployment succeeded" for application validation.
