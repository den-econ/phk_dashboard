import json, pathlib
path=pathlib.Path('PHK Early Warning Dashboard — Dewan Ekonomi update v4.html')
text=path.read_text(encoding='utf-8-sig')
gj=json.load(open('indonesia-prov.geojson',encoding='utf-8'))
geo='const INDONESIA_PROV_GEOJSON = '+json.dumps(gj,ensure_ascii=False,separators=(',',':'))+';\n'
anchor='const CANDIDATE_K = new Set([3,7,8,9,10,11,12,14,15,16,19,20,21,22,23,24,25,26]);'
if 'const INDONESIA_PROV_GEOJSON =' not in text:
    if anchor not in text:
        raise SystemExit('anchor not found')
    text=text.replace(anchor, geo+anchor)
path.write_text(text,encoding='utf-8')
print('embedded', len(geo))
