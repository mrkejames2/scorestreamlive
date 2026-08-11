
---

## `docs/MILESTONES.md`

**Purpose:** Tracks milestone progress and upcoming work.

```markdown
# Milestones

## Milestone 0 — Golden Path Validation
**Status:** Complete  
Validated the AI-assisted development pipeline: GPT → Kimi → Devin → Docker → Local VM → GitHub → Render → Production.

## Milestone 1 — Production Configuration & Observability
**Status:** In Progress  
Establish operational foundation: centralized configuration, structured logging, health endpoints, application metadata, Docker improvements.

## Milestone 2 — Database Foundation
**Status:** Planned  
Introduce PostgreSQL connection and integrate database health into `/health/ready`.

# Deployment

## Local Development

1. Copy environment variables:
   ```bash
   cp .env.example .env

## Render (Manual Database)

1. Push the repository to GitHub.
2. In Render, create a new **Web Service** from your GitHub repo.
3. Separately, create a **Managed PostgreSQL** database in Render.
4. Copy the database connection details (host, port, name, user, password) from the database dashboard.
5. In your Web Service's **Environment** tab, manually add:
   - `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
   - `APP_NAME`, `APP_ENV=production`, `APP_VERSION`, `LOG_LEVEL`
6. Deploy the web service.

# Deployment

## Local Development

1. Copy environment variables:
   ```bash
   cp .env.example .env