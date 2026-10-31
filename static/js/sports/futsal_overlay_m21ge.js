/* M21-G-E: viewport fitting only. Existing data/clock/sponsor scripts remain authoritative. */
(() => {
  'use strict';
  const board = document.getElementById('scoreboard');
  if (!board) return;
  const fit = () => {
    // Preserve the approved 1060x106 size at 1280x720 and larger viewports.
    // Scale down only when the browser source is too narrow or too short.
    const availableWidth = Math.max(1, window.innerWidth - 24);
    const availableHeight = Math.max(1, window.innerHeight - 48);
    const scale = Math.max(0.1, Math.min(1, availableWidth / 1060, availableHeight / 106));
    document.documentElement.style.setProperty('--m21ge-scale', String(scale));
  };
  window.addEventListener('resize', fit, {passive:true});
  fit();
})();
