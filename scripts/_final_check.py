import pathlib,re,json
s=pathlib.Path('PHK Early Warning Dashboard — Dewan Ekonomi update v4.html').read_text(encoding='utf-8')
checks={
 'Province Heatmap':'Province Heatmap' in s,
 'Tabel Sektor x Provinsi':'Tabel Sektor × Provinsi' in s,
 'Live button':'id="simModeLive"' in s,
 'Custom button':'id="simModeCustom"' in s,
 'Top10 option':'value="top10">Top 10 tekanan' in s,
 'Top10 dynamic slice':'sort((a,b)=>Math.abs(impact[b])-Math.abs(impact[a])).slice(0,10)' in s,
 'GeoJSON 38': len(json.loads(re.search(r'const INDONESIA_PROV_GEOJSON = (.*?);\s*const CANDIDATE_K',s,re.S).group(1))['features'])==38,
 'Exec top5 restored':'const top5 = provNames.slice(0,5);' in s,
}
for k,v in checks.items(): print(k, v)
