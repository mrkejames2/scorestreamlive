M19 AUTH-HF1 — Manager Role Semantics

Apply from repository root:
  python3 scripts/apply_m19_auth_hf1.py
  bash scripts/validate_m19_auth_hf1.sh

Manager becomes club-wide operational management inside its own club.
Operator remains explicitly assigned-game scoped.
Manager may read Sponsor Library and assign existing sponsors to games.
Sponsor Library mutation remains Director-only.
No database migration.
Existing TeamManager rows are preserved; new Manager-created teams no longer create redundant rows.
Do not commit until human acceptance.
