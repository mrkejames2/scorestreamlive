/* R4: single managed roster. Other side is a scoreboard placeholder. */
(()=>{'use strict';const id=document.body.dataset.gameId;if(!id)return;
const el=x=>document.getElementById(x);
async function req(url){const r=await fetch(url,{credentials:'same-origin',cache:'no-store',headers:{Accept:'application/json'}});if(!r.ok)throw Error(`HTTP ${r.status}`);return r.json()}
async function load(){try{const game=await req(`/api/games/${encodeURIComponent(id)}`);const note=el('roster-notice');const mine=game.my_team_id;for(const side of ['home','away']){const teamId=game[`${side}_team_id`];const managed=!!mine&&mine===teamId;const select=el(`${side}-scorer`),link=el(`${side}-roster-link`);if(select){select.closest('.scorer-picker')?.toggleAttribute('hidden',!managed);select.disabled=!managed;if(!managed)select.value='';}if(link){link.hidden=!managed;if(managed){link.href=`/teams/${encodeURIComponent(teamId)}`;link.textContent='Manage My Team Roster';}}}if(note)note.textContent=mine?'Only My Team uses player attribution. Opponent goals are recorded as team goals.':'Select My Team on the Futsal Games page to enable player scoring. Both sides can still score team goals.';
}catch(e){if(el('roster-notice'))el('roster-notice').textContent='Unable to load My Team selection: '+e.message}}
load();document.addEventListener('visibilitychange',()=>{if(!document.hidden)load()});
})();
