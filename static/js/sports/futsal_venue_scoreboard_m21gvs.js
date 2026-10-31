/* M21-G-VS: read-only venue scoreboard, authoritative Futsal snapshot and period. */
(()=>{'use strict';
const $=id=>document.getElementById(id), gid=document.body.dataset.gameId;
const state={snapshot:null,receivedAt:0,period:null,connected:false,busy:false};
function fmt(seconds){const n=Math.max(0,Math.ceil(seconds));return `${String(Math.floor(n/60)).padStart(2,'0')}:${String(n%60).padStart(2,'0')}`;}
function clock(){const c=state.snapshot?.clock;if(!c){$('venue-clock').textContent='--:--';return;}
const elapsed=Number(c.authoritative_elapsed_seconds??c.elapsed_seconds??0)+(c.status==='running'?Math.max(0,(performance.now()-state.receivedAt)/1000):0);
$('venue-clock').textContent=fmt(c.mode==='count_down'?Math.max(0,Number(c.duration_seconds||0)-elapsed):elapsed);}
function team(side,t){$(`venue-${side}-name`).textContent=t?.short_name||t?.name||side.toUpperCase();
const img=$(`venue-${side}-logo`),fallback=$(`venue-${side}-logo-fallback`);
fallback.textContent=String(t?.short_name||t?.name||side).slice(0,3).toUpperCase();
const url=String(t?.logo_url||'').trim();if(url){if(img.getAttribute('src')!==url)img.src=url;img.classList.remove('hidden');fallback.classList.add('hidden');img.onerror=()=>{img.classList.add('hidden');fallback.classList.remove('hidden');};}else{img.removeAttribute('src');img.classList.add('hidden');fallback.classList.remove('hidden');}}
function branding(b){const holder=$('venue-branding'),img=$('venue-branding-logo'),url=String(b?.logo_url||'').trim();if(!b?.enabled||!url){holder.classList.add('hidden');img.removeAttribute('src');return;}
if(img.getAttribute('src')!==url)img.src=url;img.alt=`${b.display_name||b.short_name||'Club'} logo`;holder.classList.remove('hidden');img.onerror=()=>holder.classList.add('hidden');}
function phase(){const life=state.snapshot?.lifecycle?.phase;if(life==='full_time')return 'FULL TIME';if(life==='halftime')return 'HALFTIME';
if(state.period===2)return '2ND HALF';if(state.period===1)return '1ST HALF';return ({pregame:'PREGAME',first_half:'1ST HALF',second_half:'2ND HALF'})[life]||'PREGAME';}
function render(){const x=state.snapshot;if(!x)return;const g=x.game||{};branding(x.branding);team('home',x.home_team);team('away',x.away_team);
$('venue-scoreboard').style.setProperty('--home',x.home_team?.primary_color||'#2a77ff');$('venue-scoreboard').style.setProperty('--away',x.away_team?.primary_color||'#6b7280');
$('venue-game-name').textContent=g.name||'';$('venue-home-score').textContent=g.home_score??0;$('venue-away-score').textContent=g.away_score??0;
$('venue-phase').textContent=phase();$('venue-connection').textContent=state.connected?'LIVE':'RECONNECTING';clock();}
async function refresh(){if(state.busy)return;state.busy=true;try{
const [sr,pr]=await Promise.all([fetch(`/api/public/games/${encodeURIComponent(gid)}/overlay-state`,{cache:'no-store'}),fetch(`/api/public/futsal/games/${encodeURIComponent(gid)}/period`,{cache:'no-store'})]);
if(!sr.ok||!pr.ok)throw Error(`Scoreboard HTTP ${sr.status}; period HTTP ${pr.status}`);
const [snapshot,period]=await Promise.all([sr.json(),pr.json()]);if(snapshot?.game?.id&&String(snapshot.game.id)!==gid)throw Error('Game ID mismatch');
state.snapshot=snapshot;state.period=period.period;state.receivedAt=performance.now();$('venue-error').classList.add('hidden');render();
}catch(err){console.warn('Futsal venue refresh',err);$('venue-error').classList.remove('hidden');$('venue-connection').textContent='RECONNECTING';}finally{state.busy=false;}}
const socket=typeof window.io==='function'?window.io():null;
if(socket){socket.on('connect',()=>{state.connected=true;void refresh();});socket.on('disconnect',()=>{state.connected=false;render();});
['game:updated','game:score_updated','scoring_event:created','scoring_event:updated','scoring_event:corrected','scoring_event:deleted','game:phase_updated','clock:updated'].forEach(event=>socket.on(event,p=>{if(String(p?.game_id||p?.id||'')===gid)void refresh();}));}
$('venue-fullscreen').addEventListener('click',()=>{if(document.fullscreenElement)void document.exitFullscreen();else void document.documentElement.requestFullscreen();});
document.addEventListener('fullscreenchange',()=>{$('venue-fullscreen').textContent=document.fullscreenElement?'Exit Full Screen':'Enter Full Screen';});
setInterval(clock,250);setInterval(refresh,5000);void refresh();
})();
