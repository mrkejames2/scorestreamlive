#!/usr/bin/env python3
from pathlib import Path

def replace(path, old, new, count=1):
    p = Path(path)
    s = p.read_text()
    if old not in s:
        raise SystemExit(f"STOP: expected text not found in {path}:\n{old[:260]}")
    s = s.replace(old, new, count)
    p.write_text(s)
    print(f"PASS: updated {path}")

replace(
    "templates/control/game.html",
    '''            <button id="start-first-half-button" class="lifecycle-button primary-action" type="button" data-action="start_first_half" disabled>Start First Half</button>
            <button id="end-first-half-button" class="lifecycle-button warning-action" type="button" data-action="end_first_half" disabled>End First Half</button>''',
    '''            <button id="start-first-half-button" class="lifecycle-button primary-action" type="button" data-action="start_first_half" disabled>Start First Half</button>
            <button id="clock-pause-resume-button" class="lifecycle-clock-button primary-action" type="button" disabled>Pause Clock</button>
            <button id="end-first-half-button" class="lifecycle-button warning-action" type="button" data-action="end_first_half" disabled>End First Half</button>'''
)

replace(
    "templates/control/game.html",
    '''          <div class="match-clock-actions">
            <button id="clock-pause-resume-button" class="primary-action match-clock-command" type="button" disabled>Pause Clock</button>
            <span id="clock-pause-resume-note" class="muted">Available during the first and second half.</span>
          </div>''',
    '''          <span id="clock-pause-resume-note" class="hidden" aria-hidden="true"></span>'''
)

replace(
    "templates/control/game.html",
    '''  <link rel="stylesheet" href="/static/css/product-theme-m17h-r4.css?v=m17h-r4">
''',
    '''  <link rel="stylesheet" href="/static/css/product-theme-m17h-r4.css?v=m17h-r4">
  <link rel="stylesheet" href="/static/css/control-m19-hf2-pause-clock.css?v=m19hf2-1">
'''
)

Path("static/css/control-m19-hf2-pause-clock.css").write_text('''/* M19 HF2 — relocate existing authoritative Pause/Resume Clock control. */
.lifecycle-actions {
  grid-template-columns: repeat(5, minmax(0, 1fr));
}
.lifecycle-clock-button {
  min-height: 58px;
  padding: 12px 14px;
  border: 1px solid #354559;
  border-radius: 12px;
  background: #18222e;
  color: #8998aa;
  font-weight: 850;
  cursor: not-allowed;
  opacity: .48;
}
.lifecycle-clock-button:not(:disabled) {
  cursor: pointer;
  opacity: 1;
  border-color: rgba(70,209,122,.5);
  background: rgba(70,209,122,.12);
  color: #8af0ad;
}
@media (max-width: 800px) {
  .lifecycle-actions { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .lifecycle-clock-button { min-height: 64px; }
}
@media (max-width: 520px) {
  .lifecycle-actions {
    grid-template-columns: 1fr 1fr;
    gap: 6px;
  }
  .lifecycle-button.current-action,
  .lifecycle-clock-button {
    display: block;
    width: 100%;
    min-height: 64px;
    font-size: 18px;
  }
}
@media (max-width: 360px) {
  .lifecycle-actions { grid-template-columns: 1fr; }
}
''')
print("PASS: wrote static/css/control-m19-hf2-pause-clock.css")
print()
print("M19 HF2 Pause/Resume Clock relocation applied successfully.")
print("No backend/API/database changes were made.")
print("No commit was created.")
