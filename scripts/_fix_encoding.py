import pathlib
p=pathlib.Path('PHK Early Warning Dashboard — Dewan Ekonomi update v4.html')
s=p.read_text(encoding='utf-8')
repls={'Â·':'·','â€”':'—','â€“':'–','Î”':'Δ','Î£':'Σ','Î·':'η','â‰¥':'≥','â†’':'→','â–¼':'▼','â–²':'▲','Ã—':'×'}
for a,b in repls.items(): s=s.replace(a,b)
p.write_text(s,encoding='utf-8')
print({k:s.count(k) for k in repls})
