const $=id=>document.getElementById(id);
async function req(path,opt={}){const r=await fetch(path,{headers:{"Content-Type":"application/json",...(opt.headers||{})},...opt});if(!r.ok){let d={};try{d=await r.json()}catch{}throw new Error(d.detail||`${r.status}`)}return r.status===204?null:r.json()}
let members=[],teams=[],games=[],asgn={team_managers:[],game_operators:[]};
function clear(n){while(n?.firstChild)n.removeChild(n.firstChild)}
function opt(v,t){const o=document.createElement("option");o.value=v;o.textContent=t;return o}
function row(text,fn){const d=document.createElement("div");d.className="item";const s=document.createElement("span");s.textContent=text;const b=document.createElement("button");b.type="button";b.className="remove";b.textContent="Remove";b.onclick=fn;d.append(s,b);return d}
async function load(){if(document.body.dataset.role!=="DIRECTOR")return;[members,teams,games,asgn]=await Promise.all([req("/api/admin/members"),req("/api/teams"),req("/api/games"),req("/api/admin/assignments")]);render()}
function render(){const m=$("members");clear(m);members.forEach(x=>{const d=document.createElement("div");d.className="item";d.innerHTML=`<div><strong>${x.display_name||x.email}</strong><div class="muted">${x.email} · ${x.club_role}</div></div>`;m.append(d)});
for(const [id,role] of [["manager-select","MANAGER"],["operator-select","OPERATOR"]]){const s=$(id);clear(s);members.filter(x=>x.club_role===role&&x.is_active).forEach(x=>s.append(opt(x.id,x.display_name||x.email)))}
const ts=$("team-select");clear(ts);teams.forEach(x=>ts.append(opt(x.id,x.name)));const gs=$("game-select");clear(gs);games.forEach(x=>gs.append(opt(x.id,x.name)));
const ta=$("team-assignments");clear(ta);asgn.team_managers.forEach(a=>ta.append(row(`${a.team_name} → ${a.user_name}`,async()=>{await req(`/api/admin/teams/${a.team_id}/managers/${a.user_id}`,{method:"DELETE"});await load()})));
const ga=$("game-assignments");clear(ga);asgn.game_operators.forEach(a=>ga.append(row(`${a.game_name} → ${a.user_name}`,async()=>{await req(`/api/admin/games/${a.game_id}/operators/${a.user_id}`,{method:"DELETE"});await load()})))}
$("member-form")?.addEventListener("submit",async e=>{e.preventDefault();$("member-message").textContent="";try{await req("/api/admin/members",{method:"POST",body:JSON.stringify({display_name:$("member-name").value,email:$("member-email").value,role:$("member-role").value,temporary_password:$("member-password").value})});e.target.reset();await load()}catch(err){$("member-message").textContent=err.message}});
$("team-form")?.addEventListener("submit",async e=>{e.preventDefault();if(!$("manager-select").value)return;await req(`/api/admin/teams/${$("team-select").value}/managers`,{method:"POST",body:JSON.stringify({user_id:$("manager-select").value})});await load()});
$("game-form")?.addEventListener("submit",async e=>{e.preventDefault();if(!$("operator-select").value)return;await req(`/api/admin/games/${$("game-select").value}/operators`,{method:"POST",body:JSON.stringify({user_id:$("operator-select").value})});await load()});
load().catch(e=>console.error("M15-D account load",e));
