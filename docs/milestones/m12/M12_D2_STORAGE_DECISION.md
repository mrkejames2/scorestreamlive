# M12-D2 Storage Decision

## Local development

M12-D2 uses filesystem storage behind a small storage abstraction. Docker
Compose mounts a named volume so Team logos survive app-container rebuilds.

## Public contract

Database Team state stores a URL:

```text
/api/team-logos/<generated-filename>
```

Consumers never depend on the physical storage directory.

## Render production

The current Render configuration uses the Free web-service plan. The final
M12-D release must not rely on Render's ephemeral filesystem for production
logo persistence.

Before M12-D is merged to `main`, choose one:

1. Upgrade the Render web service and attach a persistent disk.
2. Add object storage and keep the same Team logo URL/API contract.

This is a release gate, not an optional follow-up.
