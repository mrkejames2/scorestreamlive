# ScoreStreamLive AI Development System

These files define AI roles. They are guardrails, not application source code.

## Mandatory Startup

Every new AI session should first read:

```text
docs/AI_HANDOFF.md
docs/IMPLEMENTATION_MAP.md
docs/CURRENT_MILESTONE_STATUS.md
docs/ai/GOLDEN_RULE.md
```

Then inspect the actual repository.

## Roles

```text
GPT            Architecture authority
Kimi           Primary implementation engineer
Devin          Environment / Git / deployment executor
DeepSeek       Independent reviewer
```

The exact model can change. The **role contract** should remain stable.

## Rule

> DeepSeek recommends. GPT decides. Implementation follows approved architecture. Devin validates and deploys.

## Important

No AI should trust conversation memory over the repository.

No AI should start a future milestone because it appears on the roadmap.
