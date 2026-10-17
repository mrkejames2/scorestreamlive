const gameId = window.FUTSAL_GAME_ID;
const base = `/api/futsal/games/${gameId}/clock`;
const $ = id => document.getElementById(id);
let current = null;
let loadedAt = 0;
const format = seconds => { const n=Math.max(0,Math.ceil(seconds));return `${String(Math.floor(n/60)).padStart(2,'0')}:${String(n%60).padStart(2,'0')}`; };
function render(){
 if(!current)return;
 const running = current.status === 'running';
 const extra = running ? Math.max(0, Math.floor((Date.now()-loadedAt)/1000)) : 0;
 $('time').textContent = format(current.display_seconds-extra);
 $('details').textContent = `Half ${current.period} · ${current.clock_policy.replace('_',' ')} · ${current.period_seconds/60} minutes`;
 $('status').textContent = current.status.toUpperCase();
 document.querySelectorAll('[data-action]').forEach(button=>{
   const action=button.dataset.action;
   button.disabled = action==='start' ? current.status!=='stopped' : action==='pause' ? !running : action==='resume' ? current.status!=='paused' : action==='reset' ? running : current.period!==1||running;
 });
}
async function call(url, method='GET', body){
 const response=await fetch(url,{method,headers:{'Accept':'application/json',...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,cache:'no-store'});
 if(!response.ok){let message=`HTTP ${response.status}`;try{message=(await response.json()).detail||message}catch{}throw new Error(message)}
 return response.json();
}
async function refresh(){
 try{current=await call(base);loadedAt=Date.now();$('setup').hidden=true;$('controls').hidden=false;$('error').textContent='';render()}
 catch(e){if(e.message==='Futsal clock is not initialized'){$('setup').hidden=false;$('controls').hidden=true;$('error').textContent=''}else{$('error').textContent=e.message}}
}
$('initialize').addEventListener('click',async()=>{try{current=await call(base,'POST',{period_seconds:Number($('minutes').value)*60,clock_policy:$('policy').value});loadedAt=Date.now();await refresh()}catch(e){$('error').textContent=e.message}});
document.querySelectorAll('[data-action]').forEach(button=>button.addEventListener('click',async()=>{try{button.disabled=true;current=await call(`${base}/${button.dataset.action}`,'POST',{expected_version:current.version});loadedAt=Date.now();$('error').textContent='';render()}catch(e){$('error').textContent=e.message;await refresh()}}));
setInterval(render,250);
setInterval(()=>{if(current)refresh()},10000);
refresh();
