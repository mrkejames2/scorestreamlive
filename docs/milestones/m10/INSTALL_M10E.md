# ScoreStreamLive M10-E — Match-Day UX

## Install
Copy files into matching repo paths, then:

```bash
chmod +x scripts/validate_m10e.sh
chmod +x scripts/create_m10e_demo.sh
sudo docker compose down
sudo docker compose up --build -d
```

## Validate
```bash
sudo BASE_URL="http://192.168.12.133:8000" ./scripts/validate_m10e.sh
```

## Human/Product checkpoint
```bash
BASE_URL="http://192.168.12.133:8000" ./scripts/create_m10e_demo.sh
```

Open the printed URL and verify:
- score and clock are visually dominant
- phase/connection/operator state is obvious
- lifecycle controls are touch-friendly
- Home/Away scoring controls are obvious
- scorer selection is usable
- goal tap gives immediate feedback
- halftime/full-time states are clear
- mobile/tablet layout has no horizontal scrolling
- two browsers stay synchronized

M10-E is complete only when automated validation and human acceptance both pass.
