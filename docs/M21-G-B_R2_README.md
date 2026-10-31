# M21-G-B R2 — Sidebar and contrast

Requires M21-G-B installed. Root-relative ZIP; no DB migration.

```bash
cd ~/projects/scorestreamlive
unzip -o ScoreStreamLive_M21-G-B_R2.zip
python3 scripts/apply_m21g_b_r2.py
git diff --check
sudo docker compose up -d --build
```

Check `/futsal/games` on desktop and mobile. Desktop left sidebar: Games, Teams, Switch Sport. Mobile menu toggles with Escape-to-close. Confirm game creation, My Team selection, control and overlay links, and Soccer dashboard remain working. Installer saves original template to `.before-m21gb-r2` (do not commit backup). This is a **Futsal-only sidebar**, not yet a shared Soccer component. No merge/deploy.
