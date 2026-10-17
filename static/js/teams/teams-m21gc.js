(()=>{'use strict';
const layout=document.querySelector('.m21gc-layout'),menu=document.querySelector('.m21gc-menu');
if(layout&&menu){menu.addEventListener('click',()=>{const open=layout.classList.toggle('menu-open');menu.setAttribute('aria-expanded',String(open))});document.addEventListener('keydown',e=>{if(e.key==='Escape'){layout.classList.remove('menu-open');menu.setAttribute('aria-expanded','false')}})}
const sport=document.body.dataset.sport||'soccer';
const match=location.pathname.match(/^\/futsal\/teams\/([0-9a-f-]+)$/i);
if(sport==='futsal'&&match){const id=new URLSearchParams(location.search).get('game');if(id&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)){const bar=document.querySelector('.topbar');if(bar){const a=document.createElement('a');a.className='m21gc-return';a.href='/futsal/games/'+encodeURIComponent(id)+'/control';a.textContent='← Return to Game Control';bar.after(a)}}}
})();
