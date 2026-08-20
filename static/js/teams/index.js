const $ = (s) => document.querySelector(s);
const statusEl=$("#teams-status"), listEl=$("#teams-list"), emptyEl=$("#teams-empty");
const errorEl=$("#teams-error"), successEl=$("#teams-success"), refreshButton=$("#refresh-teams");
const template=$("#team-card-template"), modal=$("#team-modal"), form=$("#team-form"), formError=$("#form-error");
const summaryTotal=$("#summary-total"), summaryLogos=$("#summary-logos"), summaryBranded=$("#summary-branded");
const nameInput=$("#team-name"), shortInput=$("#team-short-name"), logoInput=$("#team-logo");
const primaryInput=$("#team-primary"), secondaryInput=$("#team-secondary");
const primaryPicker=$("#team-primary-picker"), secondaryPicker=$("#team-secondary-picker");
let teams=[], editingTeam=null, generation=0, modalReturnFocus=null;

function setStatus(state,text){statusEl.dataset.state=state;statusEl.textContent=text;}
function notice(el,msg){el.textContent=msg;el.classList.toggle("hidden",!msg);}
function color(v){return typeof v==="string"&&/^#[0-9a-fA-F]{6}$/.test(v)?v.toUpperCase():null;}
function letter(t){const s=(t.short_name||t.name||"T").trim();return s?s[0].toUpperCase():"T";}
async function json(path,options={}){
  const r=await fetch(path,{cache:"no-store",headers:{Accept:"application/json",...(options.headers||{})},...options});
  if(!r.ok){let d="";try{const b=await r.json();d=b?.detail?` — ${b.detail}`:"";}catch{}throw new Error(`HTTP ${r.status}${d}`);}
  return r.json();
}
function applyColor(sw,label,v){const c=color(v);if(c){sw.style.background=c;label.textContent=c;}else{sw.style.removeProperty("background");label.textContent="Not set";}}
function renderTeam(t){
  const n=template.content.cloneNode(true), card=n.querySelector(".team-card"), accent=n.querySelector(".team-accent");
  const p=color(t.primary_color),s=color(t.secondary_color);
  accent.style.background=p&&s?`linear-gradient(90deg,${p} 0 50%,${s} 50% 100%)`:p||s||"";
  const fallback=n.querySelector(".team-brand-fallback"),img=n.querySelector(".team-brand-logo");
  fallback.textContent=letter(t);
  if(t.logo_url){img.alt=`${t.name} logo`;img.src=t.logo_url;img.onload=()=>{img.classList.remove("hidden");fallback.classList.add("hidden")};img.onerror=()=>{img.classList.add("hidden");fallback.classList.remove("hidden")};}
  n.querySelector(".team-name").textContent=t.name||"Unnamed Team";n.querySelector(".team-short-name").textContent=t.short_name||"NO SHORT NAME";
  n.querySelector(".team-id").textContent=t.id;n.querySelector(".team-id").title=t.id;
  applyColor(n.querySelector(".primary-swatch"),n.querySelector(".primary-color"),t.primary_color);
  applyColor(n.querySelector(".secondary-swatch"),n.querySelector(".secondary-color"),t.secondary_color);
  n.querySelector(".view-team-link").href=`/teams/${t.id}`;
  n.querySelector(".manage-team-button").onclick=(event)=>openModal(t,event.currentTarget);
  card.dataset.teamId=t.id;listEl.appendChild(n);
}
function render(){
  listEl.replaceChildren();emptyEl.classList.toggle("hidden",teams.length!==0);
  summaryTotal.textContent=teams.length;
  summaryLogos.textContent=teams.filter(t=>t.logo_url).length;
  summaryBranded.textContent=teams.filter(t=>t.logo_url||color(t.primary_color)||color(t.secondary_color)).length;
  teams.forEach(renderTeam);
}
async function loadTeams(){
  const g=++generation;setStatus("loading","LOADING");refreshButton.disabled=true;notice(errorEl,"");listEl.setAttribute("aria-busy","true");
  try{const data=await json("/api/teams");if(g!==generation)return;if(!Array.isArray(data))throw new Error("Unexpected Team API response.");teams=data;render();setStatus("ready","READY");}
  catch(e){if(g!==generation)return;notice(errorEl,e.message||"Unable to load Teams.");setStatus("error","ERROR");}
  finally{if(g===generation){refreshButton.disabled=false;listEl.setAttribute("aria-busy","false");}}
}
function syncPreview(){
  const t={name:nameInput.value.trim(),short_name:shortInput.value.trim()};
  $("#preview-name").textContent=t.name||"Team Name";$("#preview-short").textContent=t.short_name||"SHORT NAME";$("#preview-letter").textContent=letter(t);
  const p=color(primaryInput.value),s=color(secondaryInput.value);$("#preview-accent").style.background=p&&s?`linear-gradient(90deg,${p} 0 50%,${s} 50% 100%)`:p||s||"";
}
function syncPicker(text,picker){const c=color(text.value);if(c)picker.value=c;}
function openModal(t=null,returnFocus=null){
  modalReturnFocus=returnFocus||document.activeElement;
  editingTeam=t;form.reset();notice(formError,"");$("#team-modal-title").textContent=t?"Edit Team":"Create Team";$("#save-team").textContent=t?"Save Changes":"Create Team";
  nameInput.value=t?.name||"";shortInput.value=t?.short_name||"";primaryInput.value=t?.primary_color||"";secondaryInput.value=t?.secondary_color||"";
  primaryPicker.value=color(t?.primary_color)||"#2A77FF";secondaryPicker.value=color(t?.secondary_color)||"#FFFFFF";
  const img=$("#preview-logo");img.classList.add("hidden");$("#preview-letter").classList.remove("hidden");
  if(t?.logo_url){img.src=t.logo_url;img.onload=()=>{img.classList.remove("hidden");$("#preview-letter").classList.add("hidden")};}
  syncPreview();modal.classList.remove("hidden");document.body.classList.add("modal-open");setTimeout(()=>nameInput.focus(),0);
}
function closeModal({restoreFocus=true}={}){
  modal.classList.add("hidden");document.body.classList.remove("modal-open");editingTeam=null;
  if(restoreFocus&&modalReturnFocus instanceof HTMLElement){modalReturnFocus.focus();}
  modalReturnFocus=null;
}
async function saveTeam(e){
  e.preventDefault();notice(formError,"");const save=$("#save-team");const originalLabel=save.textContent;save.disabled=true;save.textContent="Saving…";setStatus("loading","SAVING");
  try{
    const payload={name:nameInput.value.trim(),short_name:shortInput.value.trim()||null,primary_color:primaryInput.value.trim()||null,secondary_color:secondaryInput.value.trim()||null};
    if(!payload.name)throw new Error("Team name is required.");
    for(const k of ["primary_color","secondary_color"])if(payload[k]&&!color(payload[k]))throw new Error("Colors must use #RRGGBB format.");
    let team;
    if(editingTeam){team=await json(`/api/teams/${editingTeam.id}`,{method:"PATCH",headers:{"Content-Type":"application/json"},body:JSON.stringify(payload)});}
    else{team=await json("/api/teams",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(payload)});}
    if(logoInput.files[0]){const fd=new FormData();fd.append("logo",logoInput.files[0]);team=await json(`/api/teams/${team.id}/logo`,{method:"POST",body:fd});}
    const wasEditing=Boolean(editingTeam);closeModal({restoreFocus:false});await loadTeams();notice(successEl,`${team.name} ${wasEditing?"updated":"created"} successfully.`);setTimeout(()=>notice(successEl,""),5000);
  }catch(e){notice(formError,e.message||"Unable to save Team.");setStatus("error","ERROR");}
  finally{save.disabled=false;save.textContent=originalLabel;if(!modal.classList.contains("hidden"))setStatus("ready","READY");}
}
$("#create-team").onclick=(event)=>openModal(null,event.currentTarget);
document.querySelector(".empty-create-team").onclick=(event)=>openModal(null,event.currentTarget);
refreshButton.onclick=loadTeams;form.onsubmit=saveTeam;
document.querySelectorAll("[data-close-modal]").forEach(x=>x.onclick=()=>closeModal());
document.addEventListener("keydown",e=>{if(e.key==="Escape"&&!modal.classList.contains("hidden"))closeModal();});
[nameInput,shortInput,primaryInput,secondaryInput].forEach(x=>x.addEventListener("input",syncPreview));
primaryInput.addEventListener("input",()=>syncPicker(primaryInput,primaryPicker));secondaryInput.addEventListener("input",()=>syncPicker(secondaryInput,secondaryPicker));
primaryPicker.addEventListener("input",()=>{primaryInput.value=primaryPicker.value.toUpperCase();syncPreview();});
secondaryPicker.addEventListener("input",()=>{secondaryInput.value=secondaryPicker.value.toUpperCase();syncPreview();});
logoInput.addEventListener("change",()=>{const f=logoInput.files[0];if(!f)return;const img=$("#preview-logo");img.src=URL.createObjectURL(f);img.classList.remove("hidden");$("#preview-letter").classList.add("hidden");});
loadTeams();
