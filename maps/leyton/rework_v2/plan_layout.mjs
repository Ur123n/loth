import fs from 'node:fs';
import path from 'node:path';
const root='C:/游戏', out='C:/Users/njw/game_stage/urban_rework';
const doc=JSON.parse(fs.readFileSync(root+'/maps/leyton/slice.json','utf8'));
const inside=(x,y,r,pad=0)=>x>=r[0]-pad&&y>=r[1]-pad&&x<r[0]+r[2]+pad&&y<r[1]+r[3]+pad;
function distance(x,y,a,b){const dx=b[0]-a[0],dy=b[1]-a[1],t=Math.max(0,Math.min(1,((x-a[0])*dx+(y-a[1])*dy)/(dx*dx+dy*dy)));return Math.hypot(x-a[0]-t*dx,y-a[1]-t*dy);}
function road(m,x,y,pad=0){return m.roads.some(r=>r.rect?inside(x,y,r.rect,pad):r.points.slice(1).some((p,i)=>distance(x,y,r.points[i],p)<=r.width/2+pad));}
function wet(m,x,y,pad=0){return (m.water||[]).some(r=>r.points.slice(1).some((p,i)=>distance(x,y,r.points[i],p)<=r.width/2+pad));}
const route=(points,width,kind='secondary')=>({kind,shape:'polyline',points,width});
const m2=doc.maps.find(m=>m.map_id==='M02');
m2.roads=[route([[44,0],[44,10],[34,20],[34,32],[53,41],[58,53],[45,66],[44,80]],6,'main'),route([[34,20],[15,20],[15,47],[34,56],[45,66]],4),route([[44,10],[72,13],[74,31],[53,41],[77,50],[75,68],[45,66]],4),route([[15,47],[34,32]],3,'lane'),route([[34,56],[58,53]],3,'lane')];
m2.structures=[];m2.zones=[];m2.spawn=[44,5];m2.patrol_routes=[{id:'noble_patrol',points:m2.roads[0].points}];
const summary=[];
for(const m of doc.maps){
 const urban=['M01','M02','M03','M04'].includes(m.map_id);
 m.urban_ground=urban;
 if(!urban)continue;
 let serial=0;
 // Roads, water, the civic plaza and door approach bands are reserved before parcels.
 const free=(r)=>{for(let y=r[1];y<r[1]+r[3];y++)for(let x=r[0];x<r[0]+r[2];x++){
  if(road(m,x+.5,y+.5,.5)||wet(m,x+.5,y+.5,2)||m.structures.some(s=>inside(x+.5,y+.5,s.rect,1))||m.bridges.some(b=>inside(x+.5,y+.5,b,3)))return false;
  if(m.map_id==='M01'&&inside(x+.5,y+.5,[29,20,38,37],1))return false;
  if(Math.hypot(x-m.spawn[0],y-m.spawn[1])<4)return false;
 }return true;};
 for(const size of (m.map_id==='M02'?[[12,10],[10,9],[8,8],[6,6]]:[[8,8],[6,6]])){
  for(let y=2;y+size[1]<m.size[1]-2;y++)for(let x=2;x+size[0]<m.size[0]-2;x++){
   const r=[x,y,...size];if(!free(r))continue;
   m.structures.push({kind:m.map_id==='M02'?'noble_rowhouse':'rowhouse',label:(m.map_id==='M02'?'贵族街坊':'沿街住宅')+' '+(++serial),rect:r,pattern: m.map_id==='M03'?'timber_house':'stone_house'});
  }
 }
 m.props=[];
 const kinds=['crate','barrel','grain_sacks','notice_board','handcart','coal_basket'];
 for(let i=0;i<m.structures.length;i++){
  const s=m.structures[i],r=s.rect;
  if(s.kind==='bridge'||s.kind==='landmark')continue;
  const candidates=[[r[0]+1,r[1]+r[3]+1],[r[0]-1,r[1]+r[3]-1],[r[0]+r[2]+1,r[1]+1]];
  for(const c of candidates){
   if(c[0]<2||c[1]<3||c[0]>m.size[0]-3||c[1]>m.size[1]-3||[c,[c[0],c[1]-1]].some(q=>road(m,...q,1)||wet(m,...q,2)||m.structures.some(t=>inside(...q,t.rect,.2)))||Math.hypot(c[0]-m.spawn[0],c[1]-m.spawn[1])<5)continue;
   m.props.push({scene:'res://assets/maps/leyton/props_batch_01/scenes/'+kinds[i%6]+'.tscn',cell:c,block_rect:[c[0],c[1]-1,1,2]});break;
  }
 }
 const area=m.structures.reduce((n,s)=>n+s.rect[2]*s.rect[3],0);
 if(m.map_id==='M02'){
  const names=['宅邸A','宅邸B','宅邸C','军官会客所','私家马厩','保护水源'];
  names.forEach((name,i)=>m.structures[i].label=name);
  for(const item of [...(m.npc_spawns||[]),...(m.event_anchors||[])])item.cell=[...m.spawn];
 }
 summary.push({map:m.map_id,structures:m.structures.length,props:m.props.length,footprint_ratio:area/(m.size[0]*m.size[1])});
}
const svg=[];
for(const [i,m] of doc.maps.filter(m=>m.urban_ground).entries()){
 const ox=(i%2)*430,oy=Math.floor(i/2)*430,scale=4;
 svg.push(`<g transform="translate(${ox},${oy})"><rect width="410" height="420" fill="#191e22"/><text x="8" y="22" fill="white">${m.map_id} — ${m.structures.length} buildings</text><g transform="translate(10,35) scale(${scale})"><rect width="${m.size[0]}" height="${m.size[1]}" fill="#5a5248"/>`);
 for(const water of m.water||[])svg.push(`<polyline points="${water.points.map(p=>p.join(',')).join(' ')}" fill="none" stroke="#254554" stroke-width="${water.width}"/>`);
 for(const r of m.roads)svg.push(r.rect?`<rect x="${r.rect[0]}" y="${r.rect[1]}" width="${r.rect[2]}" height="${r.rect[3]}" fill="#baa98b"/>`:`<polyline points="${r.points.map(p=>p.join(',')).join(' ')}" fill="none" stroke="#baa98b" stroke-width="${r.width}" stroke-linejoin="round"/>`);
 for(const s of m.structures)svg.push(`<rect x="${s.rect[0]}" y="${s.rect[1]}" width="${s.rect[2]}" height="${s.rect[3]}" fill="${s.pattern?'#34464d':'#76685f'}" stroke="#bda476" stroke-width=".3"/>`);
 for(const p of m.props)svg.push(`<circle cx="${p.cell[0]}" cy="${p.cell[1]}" r=".7" fill="#df963d"/>`);
 svg.push('</g></g>');
}
fs.writeFileSync(out+'/layout_draft.svg',`<svg xmlns="http://www.w3.org/2000/svg" width="860" height="860">${svg.join('')}</svg>`);
fs.writeFileSync(out+'/slice.staged.json',JSON.stringify(doc,null,2)+'\n');
fs.writeFileSync(out+'/layout_metrics.json',JSON.stringify(summary,null,2)+'\n');
console.log(JSON.stringify(summary));
