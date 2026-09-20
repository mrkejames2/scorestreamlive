export function sponsorTiming(presentation,sponsorCount,nowMs=Date.now()){
 const count=Math.max(0,Number(sponsorCount)||0),intervalMs=Math.max(5000,(Number(presentation?.rotation_interval_seconds)||10)*1000),anchorMs=Date.parse(presentation?.updated_at||"");
 const elapsedMs=Number.isFinite(anchorMs)?Math.max(0,nowMs-anchorMs):0,position=count>0?Math.floor(elapsedMs/intervalMs)%count:0,remainder=elapsedMs%intervalMs;
 return {intervalMs,position,remainingMs:remainder===0?intervalMs:intervalMs-remainder};
}
export function preloadImage(url){return new Promise((resolve,reject)=>{const image=new Image();image.onload=()=>resolve(url);image.onerror=()=>reject(new Error(`Sponsor artwork failed to load: ${url}`));image.src=url;});}
