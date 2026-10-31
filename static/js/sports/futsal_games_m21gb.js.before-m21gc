/* M21-G-B: dashboard presentation; M21-F R4 owns My Team game creation. */
(()=>{'use strict';
const el=id=>document.getElementById(id);
const msg=s=>{el('message').textContent=s};
const esc=s=>String(s||'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
async function api(path,opts={}){const r=await fetch(path,{credentials:'same-origin',cache:'no-store',headers:{Accept:'application/json','Content-Type':'application/json'},...opts});if(!r.ok){let b;try{b=await r.json()}catch{}throw Error(b?.detail||`HTTP ${r.status}`)}return r.json()}
let games=[],teams=[];
function render(){
 const counts={live:0,scheduled:0,completed:0};
 for(const g of games){if(g.status in counts)counts[g.status]++}
 el('count-live').textContent=counts.live;el('count-upcoming').textContent=counts.scheduled;el('count-completed').textContent=counts.completed;
 const filter=el('game-filter').value, list=filter==='all'?games:games.filter(g=>g.status===filter);
 const wrap=el('games');wrap.replaceChildren();el('empty-games').classList.toggle('hidden',list.length>0);
 const names=new Map(teams.map(t=>[t.id,t.name]));
 for(const g of list){
  const card=document.createElement('article');card.className='match-card';card.dataset.status=g.status;
  const home=g.home_team?.name||names.get(g.home_team_id)||'Home',away=g.away_team?.name||names.get(g.away_team_id)||'Away';
  const mine=g.my_team_id?(names.get(g.my_team_id)||'Assigned'):'Not assigned';
  const control='/futsal/games/'+encodeURIComponent(g.id)+'/control';
  const overlay='/futsal/games/'+encodeURIComponent(g.id)+'/overlay';
  card.innerHTML=`<div class="match-top"><span class="match-status">${esc(g.status)}</span><span class="eyebrow">FUTSAL</span></div>
  <h3 class="match-name">${esc(g.name)}</h3><div class="match-teams">${esc(home)} vs ${esc(away)}<div>My Team: ${esc(mine)}</div></div>
  <div class="match-actions"><a class="button button-primary" href="${control}">Control Center</a><a class="button button-secondary" href="${overlay}" target="_blank" rel="noopener">Overlay ↗</a></div>`;
  wrap.append(card);
 }
}
async function refresh(){
 const status=el('games-status');status.textContent='LOADING';status.dataset.state='loading';
 try{[teams,games]=await Promise.all([api('/api/teams?sport=futsal'),api('/api/games?sport=futsal')]);
  for(const id of ['home-team','away-team']){const s=el(id);const prior=s.value;s.replaceChildren(new Option('Choose team',''));teams.forEach(t=>s.add(new Option(t.name,t.id)));if([...s.options].some(o=>o.value===prior))s.value=prior;}
  render();status.textContent='READY';status.dataset.state='ready';
 }catch(e){status.textContent='ERROR';status.dataset.state='error';msg('Unable to load Futsal games: '+e.message)}
}
const panel=el('new-game-panel');
el('new-game-button').onclick=()=>{panel.classList.remove('hidden');el('game-name').focus();};
el('cancel-new-game').onclick=()=>panel.classList.add('hidden');
el('refresh-games').onclick=refresh;
el('game-filter').onchange=render;
el('team-form').onsubmit=async e=>{e.preventDefault();try{await api('/api/teams',{method:'POST',body:JSON.stringify({name:el('team-name').value.trim(),short_name:el('team-short').value.trim()||null,sport:'futsal'})});msg('Futsal team created.');el('team-form').reset();await refresh();}catch(err){msg('Unable to create team: '+err.message)}};
refresh();
})();
