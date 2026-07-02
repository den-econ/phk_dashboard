import pathlib,re
s=pathlib.Path('PHK Early Warning Dashboard — Dewan Ekonomi update v4.html').read_text(encoding='utf-8')
print('mojibake markers', sum(s.count(x) for x in ['Â','Î','â€”']))
m=re.search(r'const tip=`(.{0,180})`;',s)
print(m.group(1) if m else 'no tip')
print('map renderer', 'renderSimProvinceMaps(contrib, sectors);' in s)
print('geojson', 'const INDONESIA_PROV_GEOJSON =' in s)
