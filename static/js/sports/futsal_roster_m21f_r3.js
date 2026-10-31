/* R3 uses existing authenticated /api/teams/{id}/players and /teams/{id}. */
(()=>{'use strict';const gameId=document.body.dataset.gameId;
const selectFor=side=>document.getElementById(`${side}-scorer`);
const linkFor=side=>document.getElementById(`${side}-roster-link`);
const state={teams:{},players:{home:[],away:[]}};
async function request(path){const r=await fetch(path,{credentials:'same-origin',cache:'no-store',headers:{Accept:'application/json'}});if(!r.ok)throw Error(`HTTP ${r.status}`);return r.json()}
function fill(side,players){const sel=selectFor(side);if(!sel)return;const chosen=sel.value;sel.replaceChildren(new Option('Team goal / unknown scorer',''));for(const p of players){const name=`${p.jersey_number==null?'—':'#'+p.jersey_number} ${p.first_name} ${p.last_name}`;sel.add(new Option(name,p.id))}if([...sel.options].some(o=>o.value===chosen))sel.value=chosen;}
async function load(){try{const g=await request(`/api/games/${encodeURIComponent(gameId)}`);if(g.sport!=='futsal')throw Error('Not a futsal game');for(const side of ['home','away']){const id=g[`${side}_team_id`];if(!id)continue;const players=await request(`/api/teams/${encodeURIComponent(id)}/players`);state.players[side]=players;state.teams[side]=id;fill(side,players);const link=linkFor(side);if(link){link.href=`/teams/${encodeURIComponent(id)}`;link.hidden=false;}}document.getElementById('roster-notice').textContent='Select a player before recording a goal, or leave Team goal selected.';window.dispatchEvent(new Event('futsal-rosters-loaded'));}catch(e){document.getElementById('roster-notice').textContent=`Unable to load rosters: ${e.message}. Goals may still be recorded without a named scorer.`;}}
window.futsalR3Roster={getPlayers:side=>state.players[side]||[],reload:load};load();document.addEventListener('visibilitychange',()=>{if(!document.hidden)load()});
})();
