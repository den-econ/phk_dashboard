import pathlib
path=pathlib.Path('PHK Early Warning Dashboard — Dewan Ekonomi update v4.html')
text=path.read_text(encoding='utf-8')
anchor="function buildFullSimTablePayload(){"
insert=r'''
function simGeoProvinceName(raw){
  const key = String(raw||'').toUpperCase().replace(/\./g,'').replace(/\s+/g,' ').trim();
  const map = {
    'DI ACEH':'Aceh','ACEH':'Aceh','DAERAH ISTIMEWA YOGYAKARTA':'DI Yogyakarta','NUSATENGGARA BARAT':'Nusa Tenggara Barat','NUSA TENGGARA BARAT':'Nusa Tenggara Barat',
    'DKI JAKARTA':'DKI Jakarta','JAWA BARAT':'Jawa Barat','JAWA TENGAH':'Jawa Tengah','JAWA TIMUR':'Jawa Timur','SUMATERA UTARA':'Sumatera Utara','SUMATERA BARAT':'Sumatera Barat','SUMATERA SELATAN':'Sumatera Selatan',
    'BANGKA BELITUNG':'Bangka Belitung','KEPULAUAN RIAU':'Kepulauan Riau','KALIMANTAN BARAT':'Kalimantan Barat','KALIMANTAN TENGAH':'Kalimantan Tengah','KALIMANTAN SELATAN':'Kalimantan Selatan','KALIMANTAN TIMUR':'Kalimantan Timur','KALIMANTAN UTARA':'Kalimantan Utara',
    'SULAWESI UTARA':'Sulawesi Utara','SULAWESI TENGAH':'Sulawesi Tengah','SULAWESI SELATAN':'Sulawesi Selatan','SULAWESI TENGGARA':'Sulawesi Tenggara','SULAWESI BARAT':'Sulawesi Barat','MALUKU UTARA':'Maluku Utara','PAPUA BARAT':'Papua Barat','NUSA TENGGARA TIMUR':'Nusa Tenggara Timur'
  };
  return map[key] || key.toLowerCase().replace(/\b\w/g,c=>c.toUpperCase());
}
function simGeoRings(geom){
  if(!geom) return [];
  if(geom.type==='Polygon') return geom.coordinates;
  if(geom.type==='MultiPolygon') return geom.coordinates.flat();
  return [];
}
function simGeoBounds(){
  const pts=[];
  INDONESIA_PROV_GEOJSON.features.forEach(f=>simGeoRings(f.geometry).forEach(r=>r.forEach(p=>pts.push(p))));
  const xs=pts.map(p=>p[0]), ys=pts.map(p=>p[1]);
  return {minX:Math.min(...xs),maxX:Math.max(...xs),minY:Math.min(...ys),maxY:Math.max(...ys)};
}
function simGeoPath(geom,b,w,h){
  const pad=8, geoRatio=(b.maxX-b.minX)/(b.maxY-b.minY), boxRatio=(w-2*pad)/(h-2*pad);
  let ox=pad, oy=pad, pw=w-2*pad, ph=h-2*pad;
  if(boxRatio>geoRatio){ const nw=ph*geoRatio; ox+=(pw-nw)/2; pw=nw; } else { const nh=pw/geoRatio; oy+=(ph-nh)/2; ph=nh; }
  const project = p=>[ox + (p[0]-b.minX)/(b.maxX-b.minX)*pw, oy + (1-(p[1]-b.minY)/(b.maxY-b.minY))*ph];
  return simGeoRings(geom).map(r=>{
    const pts=r.map(project);
    return pts.length ? 'M'+pts.map(p=>p[0].toFixed(1)+','+p[1].toFixed(1)).join('L')+'Z' : '';
  }).join(' ');
}
function simMapColor(v,lim){
  if(v==null || !isFinite(v)) return '#eef1f5';
  const a=Math.min(Math.abs(v)/(lim||1),1), target=v<0?[210,59,52]:[31,157,87], base=[241,244,248];
  const rgb=base.map((x,i)=>Math.round(x+(target[i]-x)*(0.18+a*0.76)));
  return `rgb(${rgb[0]},${rgb[1]},${rgb[2]})`;
}
function computeProvinceThemeImpact(contrib,sectors,provinces){
  const out={};
  provinces.forEach(prov=>{
    out[prov]={total:0,t1:0,t2:0,t3:0};
    sectors.forEach(sec=>{
      const emp=((LO_EMP[prov]||{})[sec.code]||0), c=contrib[sec.code];
      out[prov].t1 += emp*c.t1/100; out[prov].t2 += emp*c.t2/100; out[prov].t3 += emp*c.t3/100; out[prov].total += emp*c.total/100;
    });
  });
  return out;
}
function renderSimProvinceMaps(contrib,sectors){
  const root=document.getElementById('simProvinceMaps');
  if(!root || !window.INDONESIA_PROV_GEOJSON && typeof INDONESIA_PROV_GEOJSON==='undefined') return;
  const activeSet=new Set(simProvincePool());
  const impacts=computeProvinceThemeImpact(contrib,sectors,SIM_PROVINCES);
  const defs=[['total','Overall','Semua theme'],['t1','Theme 1','Harga komoditas'],['t2','Theme 2','Mitra dagang'],['t3','Theme 3','Permintaan domestik']];
  const vals=[];
  INDONESIA_PROV_GEOJSON.features.forEach(f=>{ const p=simGeoProvinceName(f.properties.Propinsi); if(activeSet.has(p) && impacts[p]) defs.forEach(d=>vals.push(impacts[p][d[0]])); });
  const lim=Math.max(1,...vals.map(v=>Math.abs(v||0))), bounds=simGeoBounds(), w=460, h=190;
  root.innerHTML=defs.map(([key,title,sub])=>{
    const paths=INDONESIA_PROV_GEOJSON.features.map(f=>{
      const prov=simGeoProvinceName(f.properties.Propinsi), active=activeSet.has(prov), v=(impacts[prov]||{})[key];
      const fill=active?simMapColor(v,lim):'#eef1f5', op=active?'1':'.28';
      const tip=`${prov}: ${v==null?'tidak ada data':simSignedN(v)+' pekerja'} · ${sub}`;
      return `<path d="${simGeoPath(f.geometry,bounds,w,h)}" fill="${fill}" opacity="${op}"><title>${simEsc(tip)}</title></path>`;
    }).join('');
    return `<div class="sim-map-card"><div class="sim-map-title">${title}<span>${sub}</span></div><svg viewBox="0 0 ${w} ${h}" role="img" aria-label="${title}">${paths}</svg><div class="legend"><span>tekanan</span><span class="grad"></span><span>dukungan</span></div></div>`;
  }).join('');
}

'''
if insert.strip() not in text:
    if anchor not in text: raise SystemExit('anchor not found')
    text=text.replace(anchor, insert+anchor)
path.write_text(text,encoding='utf-8')
print('inserted map functions')
