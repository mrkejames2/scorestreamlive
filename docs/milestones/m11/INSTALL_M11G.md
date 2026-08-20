# M11-G Installation / Execution

M11-G is a certification package only. It does not replace application files.

Copy/add:

```text
scripts/validate_m11g.sh
scripts/create_m11g_demo.sh
M11G_HUMAN_ACCEPTANCE.md
M11G_RELEASE_NOTES.md
AI_HANDOFF_M11_UPDATE.md
```

Make scripts executable:

```bash
chmod +x scripts/validate_m11g.sh
chmod +x scripts/create_m11g_demo.sh
```

Run final automated gate:

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m11g.sh
```

Create final human acceptance demo:

```bash
BASE_URL="http://192.168.12.133:8000" \
  ./scripts/create_m11g_demo.sh
```

After automated + human PASS, merge the contents of `AI_HANDOFF_M11_UPDATE.md`
into the project `AI_HANDOFF.md` and mark Milestone 11 complete.
