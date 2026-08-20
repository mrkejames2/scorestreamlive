const root=document.querySelector(".detail-shell"), id=root.dataset.teamId;
const $=s=>document.querySelector(s), status=$("#detail-status"), error=$("#detail-error");
function color(v){return typeof v==="string"&&/^#[0-9a-fA-F]{6}$/.test(v)?v.toUpperCase():null}
async function get(path){const r=await fetch(path,{headers:{Accept:"application/json"},cache:"no-store"});if(!r.ok)throw new Error(`${path} returned HTTP ${r.status}`);return r.json()}
function swatch(el,label,v){const c=color(v);if(c){el.style.background=c;label.textContent=c}else{label.textContent="Not set"}}
function renderTeam(t){
 $("#team-hero").classList.remove("hidden");$("#team-name").textContent=t.name;$("#team-short").textContent=t.short_name||"NO SHORT NAME";$("#team-id").textContent=t.id;
 const p=color(t.primary_color),s=color(t.secondary_color);$("#hero-accent").style.background=p&&s?`linear-gradient(90deg,${p} 0 50%,${s} 50% 100%)`:p||s||"";
 swatch($("#primary-swatch"),$("#primary-color"),t.primary_color);swatch($("#secondary-swatch"),$("#secondary-color"),t.secondary_color);
 const fallback=$("#logo-fallback"),img=$("#team-logo"),source=(t.short_name||t.name||"T").trim();fallback.textContent=(source[0]||"T").toUpperCase();
 if(t.logo_url){img.src=t.logo_url;img.alt=`${t.name} logo`;img.onload=()=>{img.classList.remove("hidden");fallback.classList.add("hidden")}}
}
function renderRoster(players){
 $("#roster-count").textContent=players.length;$("#roster-empty").classList.toggle("hidden",players.length!==0);const list=$("#roster-list");list.replaceChildren();
 const sorted=[...players].sort((a,b)=>(a.jersey_number??10000)-(b.jersey_number??10000)||a.last_name.localeCompare(b.last_name)||a.first_name.localeCompare(b.first_name));
 for(const p of sorted){const row=document.createElement("article");row.className="player-row";
  const jersey=document.createElement("div");jersey.className="jersey";jersey.textContent=p.jersey_number??"—";
  const info=document.createElement("div");const name=document.createElement("strong");name.textContent=`${p.first_name} ${p.last_name}`;const meta=document.createElement("code");meta.textContent=p.id;info.append(name,meta);
  row.append(jersey,info);list.append(row)}
}
async function load(){try{status.textContent="LOADING";const [team,players]=await Promise.all([get(`/api/teams/${id}`),get(`/api/teams/${id}/players`)]);renderTeam(team);renderRoster(players);status.textContent="READY";status.dataset.state="ready"}catch(e){error.textContent=e.message||"Unable to load Team.";error.classList.remove("hidden");status.textContent="ERROR";status.dataset.state="error"}}
load();
