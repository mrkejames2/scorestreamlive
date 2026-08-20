#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${1:-$(pwd)}"
cd "$PROJECT_ROOT"

python3 - <<'PY'
from pathlib import Path

root = Path.cwd()

def required(rel):
    path = root / rel
    if not path.exists():
        raise SystemExit(f"M12-G patch failed: missing {rel}")
    return path, path.read_text()

def save(path, old, new):
    if old == new:
        print(f"[SKIP] {path.relative_to(root)}")
    else:
        path.write_text(new)
        print(f"[PATCH] {path.relative_to(root)}")

# templates/games/index.html
path, text = required("templates/games/index.html")
old = text
css_link = '<link rel="stylesheet" href="/static/css/games-g.css">'
if css_link not in text:
    anchor = '<link rel="stylesheet" href="/static/css/games-d4.css">'
    if anchor not in text:
        raise SystemExit("M12-G patch failed: games-d4.css anchor missing")
    text = text.replace(anchor, anchor + "\n  " + css_link, 1)
indicator = '<span class="resume-indicator hidden">RESUMABLE</span>'
if indicator not in text:
    anchor = '<span class="game-clock chip"></span>'
    if anchor not in text:
        raise SystemExit("M12-G patch failed: game-clock chip anchor missing")
    text = text.replace(anchor, anchor + "\n            " + indicator, 1)
save(path, old, text)

# static/js/games/index.js
path, text = required("static/js/games/index.js")
old = text
if 'card.dataset.resumeState =' not in text:
    anchor = 'card.dataset.gameId = game.id;'
    if anchor not in text:
        raise SystemExit("M12-G patch failed: game card dataset anchor missing")
    insertion = '''card.dataset.gameId = game.id;

  const active = isActive(game, lifecycle, clock);
  const completed = isCompleted(game, lifecycle);

  card.dataset.resumeState = completed
    ? "completed"
    : active
      ? "active"
      : "ready";

  const resumeIndicator = fragment.querySelector(".resume-indicator");
  resumeIndicator.classList.toggle("hidden", !active && !completed);
  resumeIndicator.textContent = completed ? "COMPLETED" : "RESUMABLE";'''
    text = text.replace(anchor, insertion, 1)
if 'hubLink.textContent =' not in text:
    old_block = '''fragment.querySelector(".hub-link").href =
    `/games/${game.id}`;'''
    if old_block not in text:
        raise SystemExit("M12-G patch failed: hub-link binding missing")
    new_block = '''const hubLink = fragment.querySelector(".hub-link");
  hubLink.href = `/games/${game.id}`;
  hubLink.textContent = completed
    ? "Review Game"
    : active
      ? "Resume Game"
      : "Open Game";'''
    text = text.replace(old_block, new_block, 1)
save(path, old, text)

# templates/games/detail.html
path, text = required("templates/games/detail.html")
old = text
css_link = '<link rel="stylesheet" href="/static/css/game-detail-g.css">'
if css_link not in text:
    anchor = '<link rel="stylesheet" href="/static/css/game-detail.css">'
    if anchor not in text:
        raise SystemExit("M12-G patch failed: game-detail.css anchor missing")
    text = text.replace(anchor, anchor + "\n  " + css_link, 1)
proof = '''    <section id="recovery-proof" class="recovery-proof hidden" aria-live="polite">
      <div class="recovery-proof-copy">
        <strong>Authoritative State Restored</strong>
        <span>This page was reconstructed from server APIs. No saved browser session is required.</span>
      </div>
      <span id="recovery-loaded-at" class="recovery-loaded-at"></span>
    </section>
'''
if 'id="recovery-proof"' not in text:
    anchor = '    <section id="match-hero" class="match-hero hidden">'
    if anchor not in text:
        raise SystemExit("M12-G patch failed: match-hero anchor missing")
    text = text.replace(anchor, proof + "\n" + anchor, 1)
save(path, old, text)

# static/js/games/detail.js
path, text = required("static/js/games/detail.js")
old = text
if 'function isResumableGame()' not in text:
    anchor = 'function render() {'
    if anchor not in text:
        raise SystemExit("M12-G patch failed: detail render anchor missing")
    helper = '''function isResumableGame() {
  if (state.lifecycle?.phase === "full_time") return false;

  return (
    ["first_half", "halftime", "second_half"].includes(state.lifecycle?.phase)
    || state.clock?.status === "running"
    || state.game?.status === "live"
  );
}

function renderRecoveryProof() {
  const proof = byId("recovery-proof");
  const loadedAt = byId("recovery-loaded-at");

  proof.classList.remove("hidden");
  loadedAt.textContent = `Loaded ${new Date().toLocaleTimeString()}`;
}

'''
    text = text.replace(anchor, helper + anchor, 1)
if 'renderRecoveryProof();' not in text:
    anchor = 'byId("readiness-grid").classList.remove("hidden");'
    if anchor not in text:
        raise SystemExit("M12-G patch failed: readiness render anchor missing")
    text = text.replace(anchor, anchor + '\n  renderRecoveryProof();', 1)
if 'Resume Control Center' not in text:
    anchor = 'byId("control-link").href = `/control/games/${game.id}`;'
    if anchor not in text:
        raise SystemExit("M12-G patch failed: control link anchor missing")
    replacement = '''byId("control-link").href = `/control/games/${game.id}`;
  byId("control-link").querySelector("strong").textContent =
    isResumableGame() ? "Resume Control Center" : "Open Control Center";'''
    text = text.replace(anchor, replacement, 1)
save(path, old, text)

print("========================================")
print("M12-G integration patch complete")
print("========================================")
PY
