/* M21-HF5: Futsal live goal callouts, using existing game-scoped Socket.IO events. */
(() => {
  'use strict';
  const gameId = String(document.body.dataset.gameId || '');
  if (!gameId) return;
  const $ = id => document.getElementById(id);
  const banner = $('futsal-goal-banner');
  if (!banner) return;
  let timeout = null;
  const recentIds = new Set();
  let snapshot = null;

  async function refreshSnapshot() {
    try {
      const response = await fetch(`/api/public/games/${encodeURIComponent(gameId)}/overlay-state`, {cache:'no-store'});
      if (!response.ok) return;
      const data = await response.json();
      if (String(data?.game?.id || '') === gameId) snapshot = data;
    } catch (error) { console.warn('Futsal goal snapshot unavailable', error); }
  }
  function teamForId(id) {
    const data = snapshot;
    if (!data) return null;
    if (String(data.game?.home_team_id || data.home_team?.id) === String(id)) return {team:data.home_team, roster:data.home_roster || []};
    if (String(data.game?.away_team_id || data.away_team?.id) === String(id)) return {team:data.away_team, roster:data.away_roster || []};
    return null;
  }
  function getScorer(playerId, roster) {
    if (!playerId) return 'TEAM GOAL';
    const player = Array.isArray(roster) ? roster.find(p => String(p.id) === String(playerId)) : null;
    if (!player) return 'GOAL SCORED';
    const name = [player.first_name, player.last_name].filter(Boolean).join(' ').trim() || player.name || player.display_name;
    return name || 'GOAL SCORED';
  }
  function remainingTime(seconds) {
    const n = Math.max(0, Math.ceil(Number(seconds)));
    if (!Number.isFinite(n)) return null;
    return `${String(Math.floor(n/60)).padStart(2,'0')}:${String(n%60).padStart(2,'0')}`;
  }
  async function showGoal(payload) {
    if (!payload || String(payload.game_id) !== gameId || payload.event_type !== 'goal') return;
    const id = String(payload.id || '');
    if (id && recentIds.has(id)) return;
    if (id) {
      recentIds.add(id);
      if (recentIds.size > 100) recentIds.delete(recentIds.values().next().value);
    }
    // The event, not a changed numeric score, triggers the celebration.
    await refreshSnapshot();
    const details = teamForId(payload.team_id);
    const team = details?.team || {};
    const teamName = team.short_name || team.name || 'FUTSAL';
    $('futsal-goal-team-name').textContent = teamName;
    $('futsal-goal-scorer').textContent = getScorer(payload.player_id, details?.roster);
    const logo = $('futsal-goal-team-logo');
    const logoUrl = typeof team.logo_url === 'string' ? team.logo_url.trim() : '';
    logo.hidden = !logoUrl;
    if (logoUrl) logo.src = logoUrl;
    else logo.removeAttribute('src');
    logo.onerror = () => { logo.hidden = true; };
    const period = payload.futsal_period === 2 ? '2ND HALF' : payload.futsal_period === 1 ? '1ST HALF' : '';
    const clock = payload.futsal_remaining_seconds == null ? '' : remainingTime(payload.futsal_remaining_seconds);
    $('futsal-goal-meta').textContent = [period,clock].filter(Boolean).join(' • ');
    banner.hidden = false;
    banner.style.animation = 'none';
    void banner.offsetWidth;
    banner.style.animation = '';
    if (timeout) clearTimeout(timeout);
    timeout = setTimeout(() => { banner.hidden = true; timeout = null; }, 5000);
  }
  void refreshSnapshot();
  // Same public overlay audience used by Soccer. Nothing is emitted or mutated.
  if (typeof window.io === 'function') {
    const socket = window.io({auth:{game_id:gameId,audience:'overlay'},transports:['websocket','polling'],reconnection:true});
    socket.on('connect', () => { void refreshSnapshot(); });
    socket.on('scoring_event:created', payload => { void showGoal(payload); });
    socket.on('game:updated', payload => { if (String(payload?.game_id || payload?.id) === gameId) void refreshSnapshot(); });
  } else {
    console.error('M21-HF5: Socket.IO client missing; goal celebrations unavailable');
  }
})();
