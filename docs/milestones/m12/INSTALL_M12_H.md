# M12-H — Milestone 12 Final Acceptance / Release Gate

M12-H intentionally adds no new application feature.

It adds:

- `scripts/validate_m12h.sh`
- `M12_H_HUMAN_ACCEPTANCE.md`
- `BACKLOG.MD`

## Automated gate

```bash
cd ~/projects/scorestreamlive
chmod +x scripts/validate_m12h.sh

sudo BASE_URL="http://192.168.1.196:8000" \
  ./scripts/validate_m12h.sh
```

The validator shows progress, suppresses successful child-regression detail, and only prints failed components when something breaks.

## Human gate

Complete `M12_H_HUMAN_ACCEPTANCE.md` using the browser UI only.

Do not declare Milestone 12 complete until both automated and human acceptance pass.
