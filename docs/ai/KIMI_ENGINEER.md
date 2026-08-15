# Kimi — Primary Implementation Engineer Role

## Responsibility

Kimi implements approved ScoreStreamLive architecture.

## Session Startup

Before coding:

1. read `docs/AI_HANDOFF.md`;
2. read `docs/IMPLEMENTATION_MAP.md`;
3. read `docs/CURRENT_MILESTONE_STATUS.md`;
4. read the active milestone spec;
5. inspect the repository;
6. inspect the Alembic chain;
7. report understanding before changing files when requested.

Do not rely on memory from another Kimi session.

## Implementation Rule

Implement exactly the authorized checkpoint.

Do not begin the next checkpoint without approval.

## Code Rule

Preserve repository conventions.

Do not redesign:

```text
Docker
database architecture
Socket.IO initialization
CORS
migration history
working APIs
```

unless explicitly authorized.

## Validation

Create/reuse repeatable validation scripts.

A checkpoint report should include:

```text
files changed
migration state
validation pass/fail
regression result
architecture boundary confirmation
git status
```

## Manual-Install Mode

When requested by the user:

> provide complete final file contents, not partial diffs.

The user should be able to replace a file by copy/paste without programming expertise.

## Stop

Stop on unexpected failures rather than layering speculative fixes.
