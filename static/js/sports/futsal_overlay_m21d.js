/* M21-D read-only overlay. Uses the existing public snapshot API, never a mutation endpoint. */
(() => {
  'use strict';
  const gameId = document.body.dataset.gameId;
  const el = id => document.getElementById(id);
  const state = { snapshot: null, receivedAt: 0, rotationOffset: 0, nextSponsorAt: 0 };
  const intervalMs = 5000;
  const format = s => {const n=Math.max(0,Math.ceil(s));return `${String(Math.floor(n/60)).padStart(2,'0')}:${String(n%60).padStart(2,'0')}`};
  function team(side, data) {
    el(side+'-name').textContent = data?.short_name || data?.name || side.toUpperCase();
    const src = typeof data?.logo_url === 'string' ? data.logo_url.trim() : '';
    const img=el(side+'-logo'); img.hidden=!src;
    if(src) {if(img.getAttribute('src')!==src) img.src=src;} else img.removeAttribute('src');
    el(side+'-initial').hidden=!!src;
    el(side+'-initial').textContent=(data?.short_name||data?.name||side).trim().slice(0,2).toUpperCase();
    img.onerror=()=>{img.hidden=true;el(side+'-initial').hidden=false};
    const color=/^#[\da-fA-F]{6}$/.test(data?.primary_color||'')?data.primary_color:'#2a77ff';
    document.documentElement.style.setProperty('--'+side+'-color',color);
  }
  function renderClock(){
    const c=state.snapshot?.clock;
    if(!c){el('clock').textContent='--:--';return;}
    const delta=c.status==='running' ? Math.max(0,(performance.now()-state.receivedAt)/1000):0;
    const elapsed=Number(c.authoritative_elapsed_seconds??c.elapsed_seconds??0)+delta;
    const duration=Number(c.duration_seconds||0);
    el('clock').textContent=format(c.mode==='count_down'?Math.max(0,duration-elapsed):elapsed);
  }
  function periodLabel(snapshot, futsalPeriod){
    if(futsalPeriod===2)return '2ND HALF';
    if(futsalPeriod===1)return '1ST HALF';
    const phase=snapshot?.lifecycle?.phase;
    const phases={pregame:'PREGAME',first_half:'1ST HALF',halftime:'HALFTIME',second_half:'2ND HALF',full_time:'FINAL'};
    if(phases[phase])return phases[phase];
    if(phase)return String(phase).replaceAll('_',' ').toUpperCase();
    return snapshot?.clock ? 'FUTSAL' : 'PREGAME';
  }
  function sponsors(snapshot){
    const list=(Array.isArray(snapshot?.sponsors)?snapshot.sponsors:[]).filter(s=>s?.artwork_url);
    const holder=el('sponsor');
    if(!list.length){holder.hidden=true;return;}
    const now=Date.now();
    if(now>=state.nextSponsorAt){state.rotationOffset++;state.nextSponsorAt=now+10000;}
    const currentId=String(snapshot?.sponsor_presentation?.current_sponsor_id||'');
    const start=Math.max(0,list.findIndex(s=>String(s.id)===currentId));
    const enabled=snapshot?.sponsor_presentation?.rotation_enabled!==false;
    const pick=list[(start+(enabled?state.rotationOffset:0))%list.length];
    if(snapshot?.sponsor_presentation?.visible===false){holder.hidden=true;return;}
    const img=el('sponsor-logo');
    if(img.getAttribute('src')!==pick.artwork_url)img.src=pick.artwork_url;
    img.onerror=()=>{holder.hidden=true};
    img.alt=(pick.name||'Sponsor')+' logo';
    holder.hidden=false;
  }
  async function update(){
    try{
      const response=await fetch(`/api/public/games/${encodeURIComponent(gameId)}/overlay-state`,{cache:'no-store',headers:{Accept:'application/json'}});
      if(!response.ok)throw new Error(`HTTP ${response.status}`);
      const snapshot=await response.json();
      if(snapshot?.game?.id && String(snapshot.game.id)!==gameId)throw new Error('Wrong game snapshot');
      state.snapshot=snapshot;state.receivedAt=performance.now();
      team('home',snapshot.home_team);team('away',snapshot.away_team);
      el('home-score').textContent=String(snapshot.game?.home_score??0);
      el('away-score').textContent=String(snapshot.game?.away_score??0);
      let futsalPeriod=null;
      try {
        const pr=await fetch(`/api/public/futsal/games/${encodeURIComponent(gameId)}/period`,{cache:'no-store'});
        if(pr.ok){const pd=await pr.json();futsalPeriod=pd.period;}
      } catch(e) {console.warn('Futsal period refresh:',e);}
      el('period').textContent=periodLabel(snapshot,futsalPeriod);
      sponsors(snapshot);renderClock();
      el('connection').hidden=true;
    }catch(e){el('connection').textContent='Overlay data unavailable — retrying';el('connection').hidden=false;console.warn('M21-D overlay refresh:',e)}
  }
  setInterval(renderClock,250);setInterval(update,intervalMs);update();
})();
