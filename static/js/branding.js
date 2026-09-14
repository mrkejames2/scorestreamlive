const byId=id=>document.getElementById(id);
const state={logoUrl:""};

function normalizeHex(value,fallback){
  const raw=String(value||"").trim();
  return /^#[0-9A-Fa-f]{6}$/.test(raw)?raw.toUpperCase():fallback;
}
function initials(value){
  const source=String(value||"CLUB").trim();
  const words=source.split(/\s+/).filter(Boolean);
  if(words.length>=2)return `${words[0][0]}${words[1][0]}`.toUpperCase();
  return source.slice(0,3).toUpperCase()||"CLUB";
}
function setMessage(message,ok=false){
  const node=byId("branding-message"); if(!node)return;
  node.textContent=message||""; node.dataset.state=ok?"ready":"error";
}
function syncColorPair(textId,pickerId,source){
  const text=byId(textId),picker=byId(pickerId); if(!text||!picker)return;
  if(source==="picker")text.value=picker.value.toUpperCase();
  if(source==="text"&&/^#[0-9A-Fa-f]{6}$/.test(text.value.trim()))picker.value=text.value.trim();
}
function renderPreview(){
  const preview=byId("branding-preview"); if(!preview)return;
  const displayName=byId("branding-display-name")?.value.trim()||"Your Club";
  const shortName=byId("branding-short-name")?.value.trim()||"CLUB";
  const primary=normalizeHex(byId("branding-primary-color")?.value,"#2A77FF");
  const secondary=normalizeHex(byId("branding-secondary-color")?.value,"#FFFFFF");
  preview.style.setProperty("--preview-primary",primary);
  preview.style.setProperty("--preview-secondary",secondary);
  byId("branding-preview-name").textContent=displayName;
  byId("branding-preview-short").textContent=shortName;
  const logo=byId("branding-preview-logo"),fallback=byId("branding-preview-fallback");
  if(state.logoUrl){
    logo.src=state.logoUrl; logo.alt=`${displayName} logo`; logo.classList.remove("hidden"); fallback.classList.add("hidden");
  }else{
    logo.removeAttribute("src"); logo.alt=""; logo.classList.add("hidden"); fallback.textContent=initials(shortName||displayName); fallback.classList.remove("hidden");
  }
}
async function api(path,options={}){
  const response=await fetch(path,{credentials:"same-origin",...options});
  const data=response.status===204?null:await response.json().catch(()=>null);
  if(!response.ok)throw new Error(data?.detail||`Request failed (${response.status})`);
  return data;
}
async function load(){
  const data=await api("/api/account/branding");
  state.logoUrl=data.logo_url||"";
  byId("branding-display-name").value=data.display_name||"";
  byId("branding-short-name").value=data.short_name||"";
  byId("branding-primary-color").value=data.primary_color||"#2A77FF";
  byId("branding-secondary-color").value=data.secondary_color||"#FFFFFF";
  byId("branding-primary-color-picker").value=normalizeHex(data.primary_color,"#2A77FF");
  byId("branding-secondary-color-picker").value=normalizeHex(data.secondary_color,"#FFFFFF");
  renderPreview();
}
byId("branding-form")?.addEventListener("submit",async event=>{
  event.preventDefault(); setMessage("");
  const payload={
    display_name:byId("branding-display-name").value.trim()||null,
    short_name:byId("branding-short-name").value.trim()||null,
    primary_color:normalizeHex(byId("branding-primary-color").value,"#2A77FF"),
    secondary_color:normalizeHex(byId("branding-secondary-color").value,"#FFFFFF"),
  };
  try{
    const data=await api("/api/account/branding",{method:"PATCH",headers:{"Content-Type":"application/json"},body:JSON.stringify(payload)});
    state.logoUrl=data.logo_url||state.logoUrl; setMessage("Branding saved.",true); renderPreview();
  }catch(error){setMessage(error.message);}
});
byId("branding-logo-upload")?.addEventListener("click",async()=>{
  const input=byId("branding-logo-input"),file=input?.files?.[0];
  if(!file){setMessage("Choose a PNG, JPEG, or WebP logo first.");return;}
  const form=new FormData(); form.append("logo",file);
  try{
    const data=await api("/api/account/branding/logo",{method:"POST",body:form});
    state.logoUrl=data.logo_url||""; setMessage("Logo uploaded.",true); renderPreview();
  }catch(error){setMessage(error.message);}
});
byId("branding-logo-remove")?.addEventListener("click",async()=>{
  try{
    await api("/api/account/branding/logo",{method:"DELETE"}); state.logoUrl="";
    const input=byId("branding-logo-input"); if(input)input.value="";
    setMessage("Logo removed.",true); renderPreview();
  }catch(error){setMessage(error.message);}
});
for(const id of["branding-display-name","branding-short-name","branding-primary-color","branding-secondary-color"]){
  byId(id)?.addEventListener("input",renderPreview);
}
byId("branding-primary-color-picker")?.addEventListener("input",()=>{syncColorPair("branding-primary-color","branding-primary-color-picker","picker");renderPreview();});
byId("branding-secondary-color-picker")?.addEventListener("input",()=>{syncColorPair("branding-secondary-color","branding-secondary-color-picker","picker");renderPreview();});
byId("branding-primary-color")?.addEventListener("change",()=>syncColorPair("branding-primary-color","branding-primary-color-picker","text"));
byId("branding-secondary-color")?.addEventListener("change",()=>syncColorPair("branding-secondary-color","branding-secondary-color-picker","text"));
load().catch(error=>setMessage(error.message));
