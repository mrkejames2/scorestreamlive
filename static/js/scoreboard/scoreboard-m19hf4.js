const $=id=>document.getElementById(id),gid=document.body.dataset.gameId,s={x:null,connected:false,anchor:0,at:0,busy:false};async function load(){if(s.busy)return;s.busy=true;try{const r=await fetch(`/api/public/games/${gid}/overlay-state`,{cache:"no-store"});if(!r.ok)throw Error(`HTTP ${r.status}`);s.x=await r.json();s.anchor=Number(s.x.clock?.authoritative_elapsed_seconds??s.x.clock?.elapsed_seconds??0);s.at=performance.now();$("venue-error").classList.add("hidden");render()}catch(e){console.error(e);$("venue-error").classList.remove("hidden")}finally{s.busy=false}}function secs(){let e=s.anchor;if(s.x?.clock?.status==="running")e+=Math.floor((performance.now()-s.at)/1000);return s.x?.clock?.mode==="count_down"?Math.max(0,Number(s.x.clock.duration_seconds||0)-e):e}function fmt(n){n=Math.max(0,Math.floor(n));return`${String(Math.floor(n/60)).padStart(2,"0")}:${String(n%60).padStart(2,"0")}`}function phase(v){return({pregame:"PREGAME",first_half:"1ST HALF",halftime:"HALFTIME",second_half:"2ND HALF",full_time:"FULL TIME"})[v]||String(v||"PREGAME").replaceAll("_"," ").toUpperCase()}function team(side,t){$(`venue-${side}-name`).textContent=t?.short_name||t?.name||side.toUpperCase();const i=$(`venue-${side}-logo`),f=$(`venue-${side}-logo-fallback`),u=t?.logo_url?(t.logo_url+(t.updated_at?`${t.logo_url.includes("?")?"&":"?"}v=${encodeURIComponent(t.updated_at)}`:"")):"";f.textContent=(t?.short_name||t?.name||side).slice(0,3).toUpperCase();if(u){i.src=u;i.classList.remove("hidden");f.classList.add("hidden");i.onerror=()=>{i.classList.add("hidden");f.classList.remove("hidden")}}else{i.classList.add("hidden");f.classList.remove("hidden")}}function branding(b){
  const wrap=$("venue-branding"),logo=$("venue-branding-logo");
  if(!wrap||!logo)return;
  const url=String(b?.logo_url||"").trim();
  if(!b?.enabled||!url){
    wrap.classList.add("hidden");
    logo.removeAttribute("src");
    return;
  }
  logo.src=url;
  logo.alt=`${b?.display_name||b?.short_name||"Club"} logo`;
  logo.onerror=()=>{
    wrap.classList.add("hidden");
    logo.removeAttribute("src");
  };
  wrap.classList.remove("hidden");
}
function render(){if(!s.x)return;branding(s.x.branding);const g=s.x.game,b=$("venue-scoreboard");b.style.setProperty("--home",s.x.home_team?.primary_color||"#2a77ff");b.style.setProperty("--away",s.x.away_team?.primary_color||"#6b7280");$("venue-game-name").textContent=g.name||"";$("venue-home-score").textContent=g.home_score??0;$("venue-away-score").textContent=g.away_score??0;$("venue-clock").textContent=fmt(secs());$("venue-phase").textContent=phase(s.x.lifecycle?.phase);team("home",s.x.home_team);team("away",s.x.away_team);$("venue-connection").textContent=s.connected?"LIVE":"RECONNECTING"}const sock=window.io();sock.on("connect",()=>{s.connected=true;void load()});sock.on("disconnect",()=>{s.connected=false;render()});["game:updated","game:score_updated","scoring_event:created","scoring_event:updated","scoring_event:corrected","scoring_event:deleted","game:phase_updated","clock:updated"].forEach(e=>sock.on(e,p=>{if(String(p?.game_id||p?.id||"")===gid)void load()}));$("venue-fullscreen").onclick=async()=>document.fullscreenElement?document.exitFullscreen():document.documentElement.requestFullscreen();document.addEventListener("fullscreenchange",()=>$("venue-fullscreen").textContent=document.fullscreenElement?"Exit Full Screen":"Enter Full Screen");setInterval(render,250);setInterval(load,5000);void load();
