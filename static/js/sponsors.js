const byId=id=>document.getElementById(id);
const state={sponsors:[],editingId:null};

async function api(path,options={}){
  const response=await fetch(path,{credentials:"same-origin",...options});
  const data=response.status===204?null:await response.json().catch(()=>null);
  if(!response.ok){
    let detail=data?.detail||`Request failed (${response.status})`;
    if(Array.isArray(detail)) detail=detail.map(x=>x.msg||String(x)).join("; ");
    throw new Error(detail);
  }
  return data;
}
function message(text,ok=false){const n=byId("editor-message");if(!n)return;n.textContent=text||"";n.dataset.state=ok?"ready":"error";}
function clear(node){while(node?.firstChild)node.removeChild(node.firstChild);}
function localInput(iso){if(!iso)return "";const d=new Date(iso);if(Number.isNaN(d.valueOf()))return "";const pad=n=>String(n).padStart(2,"0");return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;}
function isoOrNull(value){return value?new Date(value).toISOString():null;}
function fmtDate(value){if(!value)return "Not set";return new Date(value).toLocaleString();}
function sponsorById(id){return state.sponsors.find(x=>x.id===id);}
function renderPreview(sponsor){
  const img=byId("sponsor-preview-image"),empty=byId("sponsor-preview-empty");
  byId("sponsor-preview-name").textContent=byId("sponsor-name").value.trim()||sponsor?.name||"Sponsor";
  if(sponsor?.artwork_url){img.src=sponsor.artwork_url;img.alt=`${sponsor.name} artwork`;img.hidden=false;empty.hidden=true;}else{img.removeAttribute("src");img.alt="";img.hidden=true;empty.hidden=false;}
}
function render(){
  const c=byId("sponsor-library");clear(c);
  if(!state.sponsors.length){const e=document.createElement("div");e.className="sponsor-empty";e.innerHTML="<h3>No sponsors yet</h3><p>Create your first sponsor to begin building your Club sponsor library.</p>";c.append(e);return;}
  state.sponsors.forEach(s=>{
    const card=document.createElement("article");card.className="sponsor-card";
    const art=document.createElement("div");art.className="sponsor-card-art";
    if(s.artwork_url){const img=document.createElement("img");img.src=s.artwork_url;img.alt=`${s.name} artwork`;art.append(img);}else{art.textContent="NO ARTWORK";art.classList.add("empty");}
    const copy=document.createElement("div");copy.className="sponsor-card-copy";
    const head=document.createElement("div");head.className="sponsor-card-head";const name=document.createElement("h3");name.textContent=s.name;const badge=document.createElement("span");badge.className=`sponsor-status ${s.is_active?"active":"inactive"}`;badge.textContent=s.is_active?"ACTIVE":"INACTIVE";head.append(name,badge);
    const meta=document.createElement("div");meta.className="sponsor-meta";meta.textContent=`Order ${s.display_order} · Start: ${fmtDate(s.starts_at)} · End: ${fmtDate(s.ends_at)}`;
    copy.append(head,meta);
    if(s.website_url){const link=document.createElement("a");link.href=s.website_url;link.target="_blank";link.rel="noopener";link.textContent=s.website_url;copy.append(link);}
    const manage=document.createElement("button");manage.className="button button-secondary button-compact";manage.type="button";manage.textContent="Manage";manage.onclick=()=>editSponsor(s.id);
    card.append(art,copy,manage);c.append(card);
  });
}
async function load(){state.sponsors=await api("/api/account/sponsors");render();if(state.editingId){const s=sponsorById(state.editingId);if(s)editSponsor(s.id,false);else newSponsor();}}
function newSponsor(){state.editingId=null;byId("editor-title").textContent="New Sponsor";byId("editor-subtitle").textContent="Create a reusable sponsor record for your Club.";byId("sponsor-form").reset();byId("sponsor-active").value="true";byId("sponsor-order").value="0";byId("sponsor-save").textContent="Create Sponsor";byId("artwork-section").hidden=true;byId("delete-section").hidden=true;message("");renderPreview(null);byId("sponsor-name").focus();}
function editSponsor(id,focus=true){const s=sponsorById(id);if(!s)return;state.editingId=id;byId("editor-title").textContent=s.name;byId("editor-subtitle").textContent="Edit sponsor details and artwork.";byId("sponsor-name").value=s.name;byId("sponsor-website").value=s.website_url||"";byId("sponsor-active").value=String(s.is_active);byId("sponsor-order").value=s.display_order;byId("sponsor-start").value=localInput(s.starts_at);byId("sponsor-end").value=localInput(s.ends_at);byId("sponsor-save").textContent="Save Changes";byId("artwork-section").hidden=false;byId("delete-section").hidden=false;message("");renderPreview(s);if(focus)byId("sponsor-name").focus();}
byId("new-sponsor")?.addEventListener("click",newSponsor);byId("editor-close")?.addEventListener("click",newSponsor);byId("sponsor-name")?.addEventListener("input",()=>renderPreview(sponsorById(state.editingId)));
byId("sponsor-form")?.addEventListener("submit",async e=>{e.preventDefault();message("");const start=isoOrNull(byId("sponsor-start").value),end=isoOrNull(byId("sponsor-end").value);if(start&&end&&new Date(end)<new Date(start)){message("End Date must be greater than or equal to Start Date.");return;}const payload={name:byId("sponsor-name").value.trim(),website_url:byId("sponsor-website").value.trim()||null,is_active:byId("sponsor-active").value==="true",display_order:Number.parseInt(byId("sponsor-order").value||"0",10),starts_at:start,ends_at:end};try{if(state.editingId){await api(`/api/account/sponsors/${state.editingId}`,{method:"PATCH",headers:{"Content-Type":"application/json"},body:JSON.stringify(payload)});message("Sponsor saved.",true);}else{const created=await api("/api/account/sponsors",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(payload)});state.editingId=created.id;}await load();if(state.editingId)message("Sponsor saved.",true);}catch(err){message(err.message);}});
byId("sponsor-artwork-upload")?.addEventListener("click",async()=>{const file=byId("sponsor-artwork-input")?.files?.[0];if(!state.editingId)return;if(!file){message("Choose a PNG, JPEG, or WebP artwork file first.");return;}const form=new FormData();form.append("artwork",file);try{await api(`/api/account/sponsors/${state.editingId}/artwork`,{method:"POST",body:form});byId("sponsor-artwork-input").value="";await load();message("Artwork uploaded.",true);}catch(err){message(err.message);}});
byId("sponsor-artwork-remove")?.addEventListener("click",async()=>{if(!state.editingId)return;try{await api(`/api/account/sponsors/${state.editingId}/artwork`,{method:"DELETE"});byId("sponsor-artwork-input").value="";await load();message("Artwork removed.",true);}catch(err){message(err.message);}});
byId("sponsor-delete")?.addEventListener("click",async()=>{const s=sponsorById(state.editingId);if(!s)return;if(!window.confirm(`Delete “${s.name}”? This permanently removes the sponsor and its uploaded artwork.`))return;try{await api(`/api/account/sponsors/${s.id}`,{method:"DELETE"});state.editingId=null;await load();newSponsor();byId("page-message").textContent="Sponsor deleted.";}catch(err){message(err.message);}});
newSponsor();load().catch(err=>message(err.message));
