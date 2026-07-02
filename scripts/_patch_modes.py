import pathlib
p=pathlib.Path('PHK Early Warning Dashboard — Dewan Ekonomi update v4.html')
s=p.read_text(encoding='utf-8')
s=s.replace("return pool.slice().sort((a,b)=>Math.abs(impact[b])-Math.abs(impact[a])).slice(0,5);", "return pool.slice().sort((a,b)=>Math.abs(impact[b])-Math.abs(impact[a])).slice(0,10);")
anchor="const cgeState = {}; CGE_SHOCKS.forEach(s=>cgeState[s.id]=0);"
insert="""const cgeState = {}; CGE_SHOCKS.forEach(s=>cgeState[s.id]=0);
const LIVE_PLACEHOLDER_SHOCKS = {cpo:4,coal:-6,nickel:3,copper:-2,electronics:-1,rubber:2,oilgas:5,china:-0.5,us:0.25,japan:-0.25,singapore:0.25,malaysia:0,india:0.5,korea:-0.25,thailand:0,taiwan:-0.25,vietnam:0.25,ipr_food:2,ipr_clothing:-3,ipr_parts:-1,ipr_fuel:1,ipr_recreation:-2,ipr_ict:1,ipr_household:-1};
let simMode = 'live';"""
if anchor in s and 'LIVE_PLACEHOLDER_SHOCKS' not in s:
    s=s.replace(anchor,insert)
func_anchor="function buildSimFilters(){"
func="""
function applySimShockValues(values){
  CGE_SHOCKS.forEach(s=>{
    const v = values && Object.prototype.hasOwnProperty.call(values,s.id) ? values[s.id] : 0;
    cgeState[s.id] = +v;
    const sl=document.getElementById('csl-'+s.id), val=document.getElementById('cval-'+s.id);
    if(sl) sl.value = v;
    if(val) val.textContent = (+v>0?'+':'')+v+s.unit;
  });
}
function setSimMode(mode){
  simMode = mode;
  document.querySelectorAll('.sim-mode-btn').forEach(b=>b.classList.toggle('active', b.dataset.mode===mode));
  const live = mode === 'live';
  document.querySelectorAll('#cge-slider-wrap input[type="range"]').forEach(el=>{ el.disabled = live; el.style.opacity = live ? '.58' : '1'; });
  if(live) applySimShockValues(LIVE_PLACEHOLDER_SHOCKS);
  runCGE();
}
"""
if func_anchor in s and 'function setSimMode' not in s:
    s=s.replace(func_anchor,func+func_anchor)
# Wire buttons in buildSim before slider listeners
wire_anchor="  buildSimFilters();\n  CGE_SHOCKS.forEach(s=>{"
wire="""  buildSimFilters();
  document.getElementById('simModeLive')?.addEventListener('click', ()=>setSimMode('live'));
  document.getElementById('simModeCustom')?.addEventListener('click', ()=>setSimMode('custom'));
  CGE_SHOCKS.forEach(s=>{"""
s=s.replace(wire_anchor, wire)
# Reset should switch to custom, zeros, enable sliders
old="""  document.getElementById('cgeReset').addEventListener('click', ()=>{
    CGE_SHOCKS.forEach(s=>{ cgeState[s.id]=0; document.getElementById('csl-'+s.id).value=0; document.getElementById('cval-'+s.id).textContent='0'+s.unit; });
    runCGE();
  });
  runCGE();"""
new="""  document.getElementById('cgeReset').addEventListener('click', ()=>{
    setSimMode('custom');
    applySimShockValues({});
    runCGE();
  });
  setSimMode('live');"""
if old in s:
    s=s.replace(old,new)
else:
    raise SystemExit('reset block not found')
p.write_text(s,encoding='utf-8')
print('patched mode and top10')
