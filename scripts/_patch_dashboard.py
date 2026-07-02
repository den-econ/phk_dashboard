import json, pathlib, re
p=pathlib.Path('PHK Early Warning Dashboard — Dewan Ekonomi update v4.html')
s=p.read_text(encoding='utf-8')
# Replace embedded geojson with 38 province file
gj=json.load(open('38 Provinsi Indonesia - Provinsi.json', encoding='utf-8'))
geo='const INDONESIA_PROV_GEOJSON = '+json.dumps(gj,ensure_ascii=False,separators=(',',':'))+';'
s=re.sub(r'const INDONESIA_PROV_GEOJSON = \{.*?\};\nconst CANDIDATE_K', geo+'\nconst CANDIDATE_K', s, count=1, flags=re.S)
# Add/adjust CSS
css_anchor='/* simulator */'
css='''
.sim-mode-grid{display:grid;grid-template-columns:repeat(2,1fr);margin:14px 0;gap:16px}
.sim-mode-btn{appearance:none;text-align:left;border:1px solid var(--line);background:var(--surface);border-radius:var(--radius);box-shadow:var(--shadow);padding:14px 16px;cursor:pointer;border-left:4px solid var(--line);transition:.15s}
.sim-mode-btn h3{font-size:13px;margin:0 0 3px;font-weight:800;color:var(--ink)}
.sim-mode-btn p{font-size:11.5px;color:var(--muted);margin:0;line-height:1.45}
.sim-mode-btn.active{border-color:var(--accent);border-left-color:var(--accent);background:#f8fbff;box-shadow:0 0 0 2px rgba(37,99,235,.08)}
.sim-mode-btn[data-mode="live"].active{border-left-color:var(--navy-3)}
'''
if '.sim-mode-grid' not in s:
    s=s.replace(css_anchor, css+css_anchor)
# Replace mode cards with buttons
old='''  <div class="grid" style="grid-template-columns:repeat(2,1fr);margin:14px 0">
    <div class="card" style="padding:14px 16px;border-left:4px solid var(--navy-3)"><h3>Versi 1 · Live / routine update</h3><p class="csub" style="margin-bottom:0">Mengambil data terbaru dari sumber/API, lalu menghasilkan province map dan matriks sektor-provinsi secara rutin.</p></div>
    <div class="card" style="padding:14px 16px;border-left:4px solid var(--accent)"><h3>Versi 2 · Custom scenario</h3><p class="csub" style="margin-bottom:0">User mengatur shock secara manual untuk melihat perubahan dampak terhadap 52 sektor dan provinsi.</p></div>
  </div>
'''
new='''  <div class="sim-mode-grid" role="group" aria-label="Mode monitor sektor-provinsi">
    <button type="button" class="sim-mode-btn active" id="simModeLive" data-mode="live"><h3>Versi 1 · Live / routine update</h3><p>Mengambil data terbaru dari sumber/API. Untuk sementara memakai nilai placeholder live sampai koneksi data/API aktif.</p></button>
    <button type="button" class="sim-mode-btn" id="simModeCustom" data-mode="custom"><h3>Versi 2 · Custom scenario</h3><p>User mengatur shock secara manual untuk melihat perubahan tekanan terhadap 52 sektor dan provinsi.</p></button>
  </div>
'''
if old in s: s=s.replace(old,new)
# Replace card body: maps first, then table header/toolbar, then table
old_block='''      <div class="card">
        <div class="card-head"><div><h3>Heatmap Sektor × Provinsi</h3><p class="csub">Sel = estimasi perubahan tenaga kerja per sektor-provinsi. Default menampilkan 5 provinsi dengan tekanan terbesar dari skenario aktif.</p></div>
          <span class="gapnote" style="font-size:10px">menunggu tensor elastisitas resmi</span></div>
        <div class="toolbar" style="margin:4px 0 10px;gap:8px;flex-wrap:wrap">
          <select id="simIsland" class="btn" style="padding:4px 8px"></select>
          <select id="simProvince" class="btn" style="padding:4px 8px"></select>
          <select id="simSectorGroup" class="btn" style="padding:4px 8px">
            <option value="all">Semua sektor</option>
            <option value="agri">Pertanian, kehutanan, perikanan</option>
            <option value="mining">Pertambangan</option>
            <option value="manuf">Manufaktur</option>
            <option value="services">Utilitas, konstruksi, dan jasa</option>
            <option value="tradable">Tradable set K</option>
          </select>
          <button class="btn" id="simFullTableBtn" style="padding:4px 8px">Buka tabel lengkap</button>
        </div>
        <div class="card-head" style="margin:6px 0 4px"><div><h3>Province Map</h3><p class="csub">Empat peta provinsi: overall dan kontribusi masing-masing theme. Nilai peta menjumlahkan 52 sektor tanpa agregasi sektor.</p></div></div>
        <div class="sim-map-grid" id="simProvinceMaps"></div>
        <div class="sim-heat-wrap"><table class="tbl heat sim-heat" id="cgeMatrix"></table></div>
      </div>
'''
new_block='''      <div class="card">
        <div class="card-head"><div><h3>Province Heatmap</h3><p class="csub">Empat peta provinsi: overall dan kontribusi masing-masing theme. Nilai peta menjumlahkan 52 sektor tanpa agregasi sektor.</p></div>
          <span class="gapnote" style="font-size:10px">menunggu tensor elastisitas resmi</span></div>
        <div class="sim-map-grid" id="simProvinceMaps"></div>
        <div class="card-head" style="margin:12px 0 6px"><div><h3>Tabel Sektor × Provinsi</h3><p class="csub">Sel = estimasi perubahan tenaga kerja per sektor-provinsi. Default menampilkan 10 provinsi dengan tekanan terbesar dari skenario aktif.</p></div></div>
        <div class="toolbar" style="margin:4px 0 10px;gap:8px;flex-wrap:wrap">
          <select id="simIsland" class="btn" style="padding:4px 8px"></select>
          <select id="simProvince" class="btn" style="padding:4px 8px"></select>
          <select id="simSectorGroup" class="btn" style="padding:4px 8px">
            <option value="all">Semua sektor</option>
            <option value="agri">Pertanian, kehutanan, perikanan</option>
            <option value="mining">Pertambangan</option>
            <option value="manuf">Manufaktur</option>
            <option value="services">Utilitas, konstruksi, dan jasa</option>
            <option value="tradable">Tradable set K</option>
          </select>
          <button class="btn" id="simFullTableBtn" style="padding:4px 8px">Buka tabel lengkap</button>
        </div>
        <div class="sim-heat-wrap"><table class="tbl heat sim-heat" id="cgeMatrix"></table></div>
      </div>
'''
if old_block not in s:
    raise SystemExit('layout block not found')
s=s.replace(old_block,new_block)
# top 5 -> top 10 in sim logic/copy only
s=s.replace("const selected = (document.getElementById('simProvince')||{}).value || 'top5';", "const selected = (document.getElementById('simProvince')||{}).value || 'top10';")
s=s.replace("if(selected==='top5')", "if(selected==='top10')")
s=s.replace('.slice(0,5);', '.slice(0,10);', 1)
s=s.replace("return pool.includes(selected) ? [selected] : pool.slice(0,5);", "return pool.includes(selected) ? [selected] : pool.slice(0,10);")
s=s.replace("const current = provSel.value || 'top5';", "const current = provSel.value || 'top10';")
s=s.replace("<option value=\"top5\">Top 5 tekanan</option>", "<option value=\"top10\">Top 10 tekanan</option>")
s=s.replace("? current : 'top5';", "? current : 'top10';")
# map property name support for 38-province geojson
s=s.replace("simGeoProvinceName(f.properties.Propinsi)", "simGeoProvinceName(f.properties.PROVINSI || f.properties.Propinsi)")
# cge narrative table wording
s=s.replace('heatmap sektor × provinsi terpilih', 'tabel sektor × provinsi terpilih')
p.write_text(s,encoding='utf-8')
print('patched layout/modes/top10/geojson')
