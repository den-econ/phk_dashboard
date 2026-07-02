import json, random, os
from PIL import Image, ImageDraw, ImageFont
random.seed(42)
gj=json.load(open('indonesia-prov.geojson',encoding='utf-8'))
features=gj['features']
coords=[]
def walk(g):
    if isinstance(g[0], (int,float)):
        coords.append(tuple(g))
    else:
        for x in g: walk(x)
for f in features:
    walk(f['geometry']['coordinates'])
xs=[c[0] for c in coords]; ys=[c[1] for c in coords]
minx,maxx,miny,maxy=min(xs),max(xs),min(ys),max(ys)
W,H=1800,1040
margin=58; title_h=92; gap=42
panel_w=(W-2*margin-gap)//2; panel_h=(H-title_h-margin-gap)//2
vals={}
for f in features:
    name=f['properties'].get('Propinsi','')
    t1=random.gauss(0,1.0); t2=random.gauss(0,0.8); t3=random.gauss(0,0.7)
    vals[name]={'Theme 1':t1,'Theme 2':t2,'Theme 3':t3,'Overall':t1+t2+t3}
allv=[v[k] for v in vals.values() for k in ['Overall','Theme 1','Theme 2','Theme 3']]
lim=max(abs(min(allv)), abs(max(allv)))
red=(210,59,52); green=(31,157,87); neutral=(241,244,248); border=(255,255,255); navy=(14,36,56); muted=(100,116,139); line=(221,227,234)
def blend(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))
def color(v):
    t=min(abs(v)/lim,1)
    return blend(neutral, red if v<0 else green, 0.18+0.78*t)
def font(size,bold=False):
    paths=[r'C:\Windows\Fonts\arialbd.ttf' if bold else r'C:\Windows\Fonts\arial.ttf', r'C:\Windows\Fonts\segoeuib.ttf' if bold else r'C:\Windows\Fonts\segoeui.ttf']
    for p in paths:
        try: return ImageFont.truetype(p,size)
        except Exception: pass
    return ImageFont.load_default()
img=Image.new('RGB',(W,H),'white'); draw=ImageDraw.Draw(img)
draw.text((margin,24),'Contoh Output Province Map - Dampak PHK Sektor-Provinsi',fill=navy,font=font(34,True))
draw.text((margin,64),'Mockup simulasi acak: 4 peta provinsi untuk Overall dan kontribusi Theme 1-3. Sektor tetap 52 sektor di matrix/detail.',fill=muted,font=font(18))
def project(x,y,box):
    bx,by,bw,bh=box
    sx=(x-minx)/(maxx-minx); sy=(y-miny)/(maxy-miny)
    return (bx+sx*bw, by+(1-sy)*bh)
def rings(geom):
    cs=geom['coordinates']; typ=geom['type']
    if typ=='Polygon': return cs
    if typ=='MultiPolygon':
        out=[]
        for poly in cs: out.extend(poly)
        return out
    return []
def nice(n):
    return n.title().replace('Dki','DKI').replace('Daerah Istimewa Yogyakarta','DI Yogyakarta').replace('Nusatenggara','Nusa Tenggara')
def draw_map(box,key,label):
    x,y,w,h=box
    draw.rounded_rectangle((x,y,x+w,y+h),radius=10,fill=(247,249,252),outline=line,width=1)
    draw.text((x+18,y+14),label,fill=navy,font=font(22,True))
    draw.text((x+18,y+43),'Warna = estimasi delta pekerja agregat provinsi; merah lebih tertekan, hijau lebih tertopang',fill=muted,font=font(13))
    mapbox=(x+20,y+72,w-40,h-116)
    mbx,mby,mbw,mbh=mapbox
    geo_ratio=(maxx-minx)/(maxy-miny); box_ratio=mbw/mbh
    if box_ratio>geo_ratio:
        neww=mbh*geo_ratio; mbx+=(mbw-neww)/2; mbw=neww
    else:
        newh=mbw/geo_ratio; mby+=(mbh-newh)/2; mbh=newh
    pbox=(mbx,mby,mbw,mbh)
    for f in features:
        v=vals[f['properties']['Propinsi']][key]
        for ring in rings(f['geometry']):
            pts=[project(a,b,pbox) for a,b,*rest in ring]
            if len(pts)>=3: draw.polygon(pts,fill=color(v),outline=border)
    lx,ly=x+20,y+h-34; lw=170
    for i in range(lw):
        vv=-lim + 2*lim*i/(lw-1); draw.line((lx+i,ly,lx+i,ly+10),fill=color(vv))
    draw.text((lx,ly+14),'tekanan',fill=muted,font=font(11)); draw.text((lx+lw-48,ly+14),'dukungan',fill=muted,font=font(11))
    worst=sorted(vals.items(), key=lambda kv:kv[1][key])[:3]
    txt='Top tekanan: '+', '.join(nice(n) for n,_ in worst)
    draw.text((x+w-420,y+h-28),txt,fill=muted,font=font(12))
panels=[(margin,title_h,panel_w,panel_h),(margin+panel_w+gap,title_h,panel_w,panel_h),(margin,title_h+panel_h+gap,panel_w,panel_h),(margin+panel_w+gap,title_h+panel_h+gap,panel_w,panel_h)]
for box,key,label in zip(panels,['Overall','Theme 1','Theme 2','Theme 3'],['Overall - Semua Theme','Theme 1 - Harga Komoditas','Theme 2 - Mitra Dagang','Theme 3 - Permintaan Domestik']):
    draw_map(box,key,label)
out='contoh_4_province_maps_phk.png'
img.save(out)
print(os.path.abspath(out))
