/* M21-G-D: presentation-only enhancements. Existing M21-F scripts own state and mutations. */
(()=>{'use strict';
const id=document.body.dataset.gameId;if(!id)return;
const main=document.querySelector('.main');const header=document.querySelector('.page-header');
if(header){const a=document.createElement('a');a.className='m21gd-return';a.href='/futsal/games';a.textContent='← Back to Futsal Games';header.insertAdjacentElement('beforebegin',a)}
for(const nav of document.querySelectorAll('.sidebar nav,.mobile-nav')){
 const links=[...nav.querySelectorAll('a')];for(const a of links){if(a.getAttribute('href')==='/futsal/games#futsal-rosters')a.href='/futsal/teams';if(a.getAttribute('href')===`/futsal/overlay/games/${id}`)a.href=`/futsal/games/${encodeURIComponent(id)}/overlay`;}
 const games=nav.querySelector('a[href="/futsal/games"]');if(games){games.setAttribute('aria-label','Return to Futsal Games')}
}
const clockSection=[...document.querySelectorAll('.card')].find(c=>c.querySelector('[data-clock]'));
if(clockSection){const hint=document.createElement('p');hint.className='m21gd-help';hint.textContent='Clock controls use the saved match state. Start, pause, resume, and advance halves here; use Clock Setup to configure the match duration.';const actions=clockSection.querySelector('.actions');actions?.insertAdjacentElement('beforebegin',hint)}
const conn=document.getElementById('connection-state');const label=document.getElementById('connection-label');
if(conn&&label){const observer=new MutationObserver(()=>{const status=document.getElementById('notice')?.textContent||'';const failed=/failed|unavailable|error/i.test(status);conn.textContent=failed?'CHECK STATUS':'CONTROL READY';label.textContent=failed?'CHECK STATUS':'ACTIVE';});observer.observe(document.getElementById('notice'),{childList:true,characterData:true,subtree:true});conn.textContent='CONTROL READY';label.textContent='ACTIVE';}
})();
