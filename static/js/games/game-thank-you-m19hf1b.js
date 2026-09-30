import {createArtworkPicker} from "/static/js/games/broadcast-artwork-picker-m19hf6.js?v=m19hf6-2";

async function J(r){if(r.ok)return r.status===204?null:r.json();let d={};try{d=await r.json()}catch{}throw Error(d.detail||`Request failed (${r.status})`)}

export async function loadGameThankYou(gameId){
 const panel=document.getElementById("m19hf1b-thank-you-panel");if(!panel)return;
 const preview=document.getElementById("m19hf1b-thank-you-preview"),enabled=document.getElementById("m19hf1b-thank-you-enabled"),msg=document.getElementById("m19hf1b-thank-you-message"),upload=document.getElementById("m19hf1b-thank-you-upload"),remove=document.getElementById("m19hf1b-thank-you-remove"),actions=enabled.closest(".game-intro-actions");

 const picker=createArtworkPicker({
  actions,
  onSelect:async artworkId=>{
   try{
    await J(await fetch(`/api/games/${gameId}/thank-you/artwork-selection`,{method:"PUT",headers:{"Content-Type":"application/json"},body:JSON.stringify({artwork_id:artworkId})}));
    msg.textContent="Thank You Screen selected.";
    await refresh();
   }catch(e){msg.textContent=e.message}
  }
 });

 async function library(){
  const d=await J(await fetch("/api/account/broadcast-artwork",{cache:"no-store"}));
  picker.setItems(d.items);
  upload.closest("label").hidden=!d.can_manage;
 }

 async function refresh(){
  const s=await J(await fetch(`/api/games/${gameId}/thank-you`,{cache:"no-store"}));
  panel.classList.remove("hidden");
  enabled.checked=s.enabled;
  preview.src=s.image_url||"";
  preview.hidden=!s.image_url;
  picker.setSelected(s.artwork_id);
 }

 upload.onchange=async e=>{
  const f=e.target.files[0];if(!f)return;
  const n=prompt("Name this reusable artwork:",f.name.replace(/\.[^.]+$/,""));
  if(!n){e.target.value="";return}
  const fd=new FormData();fd.append("name",n);fd.append("artwork",f);
  try{
   const a=await J(await fetch("/api/account/broadcast-artwork",{method:"POST",body:fd}));
   await library();
   await J(await fetch(`/api/games/${gameId}/thank-you/artwork-selection`,{method:"PUT",headers:{"Content-Type":"application/json"},body:JSON.stringify({artwork_id:a.id})}));
   msg.textContent="Artwork uploaded and selected.";
   await refresh();
  }catch(x){msg.textContent=x.message}
  finally{e.target.value=""}
 };

 enabled.onchange=async()=>{
  try{await J(await fetch(`/api/games/${gameId}/thank-you`,{method:"PATCH",headers:{"Content-Type":"application/json"},body:JSON.stringify({enabled:enabled.checked})}))}
  catch(e){msg.textContent=e.message}
  await refresh()
 };

 remove.textContent="Clear Selection";
 remove.onclick=async()=>{
  if(!confirm("Clear this game's Thank You Screen selection? Library artwork will not be deleted."))return;
  try{
   await J(await fetch(`/api/games/${gameId}/thank-you/artwork`,{method:"DELETE"}));
   msg.textContent="Selection cleared.";
   await refresh()
  }catch(e){msg.textContent=e.message}
 };

 try{await library();await refresh()}catch(e){panel.classList.add("hidden");console.error(e)}
}
