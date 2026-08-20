# ScoreStreamLive Validation Modes

## Local full release gate

```bash
sudo VALIDATION_MODE=local \
  BASE_URL="http://192.168.1.196:8000" \
  ./scripts/validate_m12h.sh
```

Local mode runs the M12-H end-to-end gate and the cumulative M12-G recovery regression, including the Docker application-container restart.

## Production release gate

```bash
sudo VALIDATION_MODE=production \
  BASE_URL="https://scorestreamlive.onrender.com/" \
  ./scripts/validate_m12h.sh
```

Production mode runs the full M12-H end-to-end HTTP/API/browser-surface acceptance flow but skips the Docker-only M12-G restart chain.

Trailing slashes in `BASE_URL` are normalized automatically.

Expected production result:

```text
M12-H end-to-end ..... PASS
M12-G cumulative .... SKIPPED (local-only)
OVERALL ............. PASS
M12-H AUTOMATED ACCEPTANCE = PASS
MILESTONE 12 PRODUCTION RELEASE GATE = PASS
```
