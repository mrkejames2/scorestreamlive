# M10-H Installation

Copy the files into their matching repository paths.

```bash
chmod +x scripts/validate_m10h.sh
chmod +x scripts/create_m10h_demo.sh
```

M10-H has no application-code changes, so no Docker rebuild is required solely for this package.

## Automated gate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m10h.sh
```

Expected: `M10-H AUTOMATED ACCEPTANCE PASSED`

## Fresh final match

```bash
BASE_URL="http://192.168.12.133:8000" \
  ./scripts/create_m10h_demo.sh
```

Open the printed Control Center URL on at least two devices and complete `M10H_HUMAN_ACCEPTANCE.md`.

## Closeout

Update `AI_HANDOFF.md` and the implementation/architecture map with M10-A through M10-H status, authoritative state, multi-device behavior, reconnect recovery, optimistic conflicts, mobile-first UI, and final validation results.

After automated and human acceptance pass:

```bash
git status
git add .
git commit -m "Complete Milestone 10: multi-device Match Control Center"
git tag milestone-10
git push origin main
git push origin milestone-10
```
