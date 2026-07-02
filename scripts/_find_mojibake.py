import pathlib
s=pathlib.Path('PHK Early Warning Dashboard — Dewan Ekonomi update v4.html').read_text(encoding='utf-8')
for i,line in enumerate(s.splitlines(),1):
    if any(x in line for x in ['Â','Î','â€”','â–','â†','â‰','â€¢','Ã']):
        print(i, line[:220])
