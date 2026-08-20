const root=document.querySelector(".detail-shell");
const teamId=root.dataset.teamId;
const $=s=>document.querySelector(s);

const status=$("#detail-status");
const error=$("#detail-error");
const success=$("#detail-success");
const modal=$("#player-modal");
const form=$("#player-form");
const formError=$("#player-form-error");
const jerseyWarning=$("#jersey-warning");
const searchInput=$("#roster-search");
const sortInput=$("#roster-sort");

let players=[];
let editing=null;

function notice(el,message){
  el.textContent=message;
  el.classList.toggle("hidden",!message);
}

function color(value){
  return typeof value==="string"&&/^#[0-9a-fA-F]{6}$/.test(value)
    ? value.toUpperCase()
    : null;
}

async function api(path,options={}){
  const response=await fetch(path,{
    cache:"no-store",
    headers:{Accept:"application/json",...(options.headers||{})},
    ...options,
  });
  if(!response.ok){
    let detail="";
    try{
      const body=await response.json();
      detail=body?.detail?` — ${body.detail}`:"";
    }catch{}
    throw new Error(`HTTP ${response.status}${detail}`);
  }
  return response.json();
}

function swatch(el,label,value){
  const normalized=color(value);
  if(normalized){
    el.style.background=normalized;
    label.textContent=normalized;
  }else{
    el.style.removeProperty("background");
    label.textContent="Not set";
  }
}

function renderTeam(team){
  $("#team-hero").classList.remove("hidden");
  $("#team-name").textContent=team.name;
  $("#team-short").textContent=team.short_name||"NO SHORT NAME";
  $("#team-id").textContent=team.id;

  const primary=color(team.primary_color);
  const secondary=color(team.secondary_color);
  $("#hero-accent").style.background=
    primary&&secondary
      ? `linear-gradient(90deg,${primary} 0 50%,${secondary} 50% 100%)`
      : primary||secondary||"";

  swatch($("#primary-swatch"),$("#primary-color"),team.primary_color);
  swatch($("#secondary-swatch"),$("#secondary-color"),team.secondary_color);

  const fallback=$("#logo-fallback");
  const img=$("#team-logo");
  const source=(team.short_name||team.name||"T").trim();
  fallback.textContent=(source[0]||"T").toUpperCase();

  if(team.logo_url){
    img.src=team.logo_url;
    img.alt=`${team.name} logo`;
    img.onload=()=>{
      img.classList.remove("hidden");
      fallback.classList.add("hidden");
    };
    img.onerror=()=>{
      img.classList.add("hidden");
      fallback.classList.remove("hidden");
    };
  }
}

function comparePlayers(a,b){
  const mode=sortInput.value;
  if(mode==="last_name"){
    return a.last_name.localeCompare(b.last_name)
      ||a.first_name.localeCompare(b.first_name)
      ||(a.jersey_number??10000)-(b.jersey_number??10000);
  }
  if(mode==="first_name"){
    return a.first_name.localeCompare(b.first_name)
      ||a.last_name.localeCompare(b.last_name)
      ||(a.jersey_number??10000)-(b.jersey_number??10000);
  }
  return (a.jersey_number??10000)-(b.jersey_number??10000)
    ||a.last_name.localeCompare(b.last_name)
    ||a.first_name.localeCompare(b.first_name);
}

function filteredPlayers(){
  const query=searchInput.value.trim().toLowerCase();
  if(!query) return [...players];
  return players.filter(player=>{
    const name=`${player.first_name} ${player.last_name}`.toLowerCase();
    const reverse=`${player.last_name} ${player.first_name}`.toLowerCase();
    const jersey=player.jersey_number===null||player.jersey_number===undefined
      ? ""
      : String(player.jersey_number);
    return name.includes(query)||reverse.includes(query)||jersey.includes(query);
  });
}

function renderRoster(){
  const visible=filteredPlayers().sort(comparePlayers);
  $("#roster-count").textContent=String(players.length);
  $("#roster-count-label").textContent=players.length===1?"player":"players";
  $("#roster-empty").classList.toggle("hidden",players.length!==0);
  $("#roster-no-results").classList.toggle(
    "hidden",
    players.length===0||visible.length!==0,
  );

  const filtered=visible.length!==players.length;
  $("#roster-visible-count").textContent=
    filtered?`Showing ${visible.length} of ${players.length}`:`${players.length} total`;

  const list=$("#roster-list");
  list.replaceChildren();

  for(const player of visible){
    const node=$("#player-row-template").content.cloneNode(true);
    node.querySelector(".jersey").textContent=player.jersey_number??"—";
    node.querySelector(".player-name").textContent=
      `${player.first_name} ${player.last_name}`;
    node.querySelector(".player-meta").textContent=
      player.jersey_number===null||player.jersey_number===undefined
        ?"No jersey number"
        :`Jersey #${player.jersey_number}`;
    node.querySelector(".player-id").textContent=player.id;
    node.querySelector(".edit-player").onclick=()=>openPlayer(player);
    list.appendChild(node);
  }
}

async function load(){
  notice(error,"");
  try{
    status.textContent="LOADING";
    status.dataset.state="loading";
    const [team,roster]=await Promise.all([
      api(`/api/teams/${teamId}`),
      api(`/api/teams/${teamId}/players`),
    ]);
    players=roster;
    renderTeam(team);
    renderRoster();
    status.textContent="READY";
    status.dataset.state="ready";
  }catch(err){
    notice(error,err.message||"Unable to load Team.");
    status.textContent="ERROR";
    status.dataset.state="error";
  }
}

function checkJerseyWarning(){
  const raw=$("#player-jersey").value.trim();
  if(raw===""){
    notice(jerseyWarning,"");
    return;
  }
  const jersey=Number(raw);
  const conflict=players.find(
    player=>player.id!==editing?.id&&player.jersey_number===jersey,
  );
  notice(
    jerseyWarning,
    conflict
      ? `Jersey #${jersey} is also assigned to ${conflict.first_name} ${conflict.last_name}.`
      : "",
  );
}

function openPlayer(player=null){
  editing=player;
  form.reset();
  notice(formError,"");
  notice(jerseyWarning,"");

  $("#player-modal-title").textContent=player?"Edit Player":"Add Player";
  $("#save-player").textContent=player?"Save Changes":"Add Player";
  $("#player-first").value=player?.first_name||"";
  $("#player-last").value=player?.last_name||"";
  $("#player-jersey").value=player?.jersey_number??"";

  modal.classList.remove("hidden");
  document.body.classList.add("modal-open");
  checkJerseyWarning();
  setTimeout(()=>$("#player-first").focus(),0);
}

function closePlayer(){
  modal.classList.add("hidden");
  document.body.classList.remove("modal-open");
  editing=null;
}

async function savePlayer(event){
  event.preventDefault();
  notice(formError,"");

  const save=$("#save-player");
  save.disabled=true;
  const wasEditing=Boolean(editing);

  try{
    const first=$("#player-first").value.trim();
    const last=$("#player-last").value.trim();
    const raw=$("#player-jersey").value.trim();
    const jersey=raw===""?null:Number(raw);

    if(!first||!last){
      throw new Error("First and last name are required.");
    }
    if(jersey!==null&&(!Number.isInteger(jersey)||jersey<0||jersey>999)){
      throw new Error("Jersey number must be a whole number from 0 through 999.");
    }

    let saved;
    if(editing){
      saved=await api(`/api/players/${editing.id}`,{
        method:"PATCH",
        headers:{"Content-Type":"application/json"},
        body:JSON.stringify({
          first_name:first,
          last_name:last,
          jersey_number:jersey,
        }),
      });
    }else{
      saved=await api("/api/players",{
        method:"POST",
        headers:{"Content-Type":"application/json"},
        body:JSON.stringify({
          team_id:teamId,
          first_name:first,
          last_name:last,
          jersey_number:jersey,
        }),
      });
    }

    closePlayer();
    await load();
    notice(
      success,
      `${saved.first_name} ${saved.last_name} ${wasEditing?"updated":"added"} successfully.`,
    );
    setTimeout(()=>notice(success,""),4000);
  }catch(err){
    notice(formError,err.message||"Unable to save Player.");
  }finally{
    save.disabled=false;
  }
}

$("#add-player").onclick=()=>openPlayer();
form.onsubmit=savePlayer;
searchInput.addEventListener("input",renderRoster);
sortInput.addEventListener("change",renderRoster);
$("#player-jersey").addEventListener("input",checkJerseyWarning);

document.querySelectorAll("[data-close-player]").forEach(
  element=>element.onclick=closePlayer,
);
document.addEventListener("keydown",event=>{
  if(event.key==="Escape"&&!modal.classList.contains("hidden")){
    closePlayer();
  }
});

load();
