"""
Rakit workbook audit manual untuk Pak Arief.

Prinsip: setiap sel adalah RUMUS HIDUP, bukan angka tempelan, sehingga
seluruh rantai perhitungan bisa ditelusuri dari data mentah sampai ΔL.

Jalankan:  .venv/bin/python audit/scripts/build_workbook.py
Keluaran:  audit/audit_empdash.xlsx
"""
import os, json
import numpy as np, pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter as CL
from openpyxl.formatting.rule import ColorScaleRule

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
EXP  = os.path.join(ROOT, "audit", "dashboard_export")
OUT  = os.path.join(ROOT, "audit", "audit_empdash.xlsx")

H_FILL = PatternFill("solid", fgColor="1F3864")
H_FONT = Font(bold=True, color="FFFFFF", size=10)
S_FILL = PatternFill("solid", fgColor="D9E2F3")
T_FONT = Font(bold=True, size=13, color="1F3864")
OK_F   = PatternFill("solid", fgColor="C6EFCE")
BAD_F  = PatternFill("solid", fgColor="FFC7CE")
THIN   = Border(*[Side(style="thin", color="BFBFBF")]*4)

wb = Workbook(); wb.remove(wb.active)

def header(ws, row, values, start=1):
    for i, v in enumerate(values):
        c = ws.cell(row=row, column=start+i, value=v)
        c.fill, c.font = H_FILL, H_FONT
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
    ws.row_dimensions[row].height = 30

def title(ws, text, sub=""):
    ws["A1"] = text; ws["A1"].font = T_FONT
    if sub: ws["A2"] = sub; ws["A2"].font = Font(italic=True, size=9, color="666666")

# ── data bersama ─────────────────────────────────────────────────────────────
meta   = json.load(open(os.path.join(ROOT,"data","elasticity","eta_meta.json")))
agg    = json.load(open(os.path.join(ROOT,"data","output","aggregation_meta.json")))
SECT   = [f"{i:02d}_{n}" for i,n in zip(meta["sector_order"], meta["sector_labels"])]
PROV   = [f"{i}_{n}"     for i,n in zip(meta["province_order"], meta["province_labels"])]
L0     = np.load(os.path.join(ROOT,"data","output","L0_matrix.npy"))
E_dash = np.load(os.path.join(ROOT,"data","output","E_matrix.npy"))
dL_dash= np.load(os.path.join(ROOT,"data","output","dL_matrix.npy"))
inten  = pd.read_csv(os.path.join(EXP,"intensity_table.csv"), index_col=0)
shocks = pd.read_csv(os.path.join(EXP,"shocks_applied.csv")).set_index("shock")["x_value_pp"]
inten  = inten.loc[shocks.index]
NS, NP, NK = 52, 34, len(shocks)

print(f"Membangun workbook: {NS} sektor x {NP} provinsi, {NK} shock")

# ═══ 00_README ═══════════════════════════════════════════════════════════════
ws = wb.create_sheet("00_README")
title(ws, "Audit Manual Dashboard PHK (empdash)",
          "Verifikasi independen atas perhitungan dashboard — permintaan Pak Arief")
rows = [
    ("", ""),
    ("TUJUAN", ""),
    ("1", "Hitung ulang secara manual dan bandingkan dengan dashboard"),
    ("2", "Periksa perhitungan SHOCK-nya, bukan hanya hasil ke tenaga kerja"),
    ("3", "Periksa apakah kode mengambil data terkini"),
    ("4", "Kerjakan langsung seluruh matriks 52x34, bukan per sektor"),
    ("", ""),
    ("VINTAGE DATA YANG DIBANDINGKAN", ""),
    ("Theme 1 (harga komoditas)", agg["periods"]["theme1"]),
    ("Theme 2 (mitra dagang)", f'{agg["periods"]["theme2"]["current"]} - {agg["periods"]["theme2"]["prior"]}'),
    ("Theme 3 (permintaan domestik)", agg["periods"]["theme3"]),
    ("Elastisitas", "PLACEHOLDER (sintetis) - bukan hasil IndoTERM"),
    ("", ""),
    ("RANTAI PERHITUNGAN", ""),
    ("Langkah 1-2", "Data mentah -> shock x_j (38 angka, satuan percentage point)"),
    ("Langkah 3", "E[s,p] = share[s,p] x JUMLAH_j ( x_j x intensity_j[s] )"),
    ("Langkah 4", "dL[s,p] = E[s,p] / 100 x L0[s,p]"),
    ("", ""),
    ("PENYEDERHANAAN PENTING", ""),
    ("", "Semua 38 matriks elastisitas berbentuk eta_j[s,p] = intensity_j[s] x share[s,p]."),
    ("", "Terverifikasi persis untuk seluruh 38 x 52 pasangan, sehingga matriks 52x34"),
    ("", "cukup dihitung dari SATU tabel intensitas 38x52 - tidak perlu 38 matriks."),
    ("", ""),
    ("DAFTAR SHEET", ""),
    ("01_shock_T1", "Harga komoditas -> YoY -> tren 48 -> x_j   (7 shock)"),
    ("02_shock_T2", "Revisi WEO x bobot ekspor -> x_k          (23 shock)"),
    ("03_shock_T3", "Indeks ritel BI -> YoY -> tren 48 -> x_i   (8 shock)"),
    ("04_L0", "Tenaga kerja awal 52x34"),
    ("05_shares", "Pangsa provinsi per sektor 52x34 (rumus dari 04)"),
    ("06_intensity", "Tabel intensitas 38x52 + vektor w[s]"),
    ("07_E_manual", "Hasil hitung manual E (%) 52x34 (rumus)"),
    ("08_dL_manual", "Hasil hitung manual dL (orang) 52x34 (rumus)"),
    ("09_dash_E", "E dari dashboard - pembanding"),
    ("10_dash_dL", "dL dari dashboard - pembanding"),
    ("11_selisih", "Perbandingan sel per sel + ringkasan"),
    ("12_catatan", "Temuan"),
    ("", ""),
    ("CATATAN", "Semua sel matriks berupa RUMUS, bukan angka tempelan."),
    ("", "Klik sel manapun untuk menelusuri asal perhitungannya."),
]
for i,(a,b) in enumerate(rows, start=4):
    ws.cell(row=i, column=1, value=a).font = Font(bold=(b=="" and a!=""), size=10)
    ws.cell(row=i, column=2, value=b)
ws.column_dimensions["A"].width = 32; ws.column_dimensions["B"].width = 82

# ═══ 01_shock_T1 ═════════════════════════════════════════════════════════════
ws = wb.create_sheet("01_shock_T1")
title(ws, "Theme 1 — Shock Harga Komoditas",
          "x_j = YoY%(t) − rata-rata 48 periode YoY% (lag 1).  Sumber: World Bank Pink Sheet + FRED IY3344")
ps = pd.read_csv(os.path.join(ROOT,"data","cache","theme1","wb_pinksheet.csv"))
fr = pd.read_csv(os.path.join(ROOT,"data","cache","theme1","fred_IY3344.csv"))
fr["d"]=pd.to_datetime(fr.date)
fr["period"]=fr.d.dt.year.astype(str)+"M"+fr.d.dt.month.astype(str).str.zfill(2)
ps = ps.merge(fr[["period","electronics"]], on="period", how="left")
CODES = ["cpo","coal","nickel","copper","rubber","oilgas","electronics"]

hdr = ["period"]
for c in CODES: hdr += [f"{c}: harga", f"{c}: YoY%", f"{c}: tren48", f"{c}: x_j"]
header(ws, 4, hdr)
R0 = 5
for r,(_,row) in enumerate(ps.iterrows()):
    xr = R0+r
    ws.cell(row=xr, column=1, value=str(row["period"]))
    for k,c in enumerate(CODES):
        b = 2+4*k
        v = pd.to_numeric(row.get(c), errors="coerce")
        ws.cell(row=xr, column=b, value=(None if pd.isna(v) else float(v)))
        pc, yc, tc = CL(b), CL(b+1), CL(b+2)
        if r >= 12:
            ws.cell(row=xr, column=b+1,
                    value=f'=IF(OR({pc}{xr}="",{pc}{xr-12}=""),"",({pc}{xr}/{pc}{xr-12}-1)*100)')
        if r >= 12+48:
            ws.cell(row=xr, column=b+2,
                    value=f'=IF(COUNT({yc}{xr-48}:{yc}{xr-1})<48,"",AVERAGE({yc}{xr-48}:{yc}{xr-1}))')
            ws.cell(row=xr, column=b+3,
                    value=f'=IF(OR({yc}{xr}="",{tc}{xr}=""),"",{yc}{xr}-{tc}{xr})')
    for cc in range(2, 2+4*len(CODES)):
        ws.cell(row=xr, column=cc).number_format = "0.0000"
LAST = R0+len(ps)-1
ws.cell(row=LAST+2, column=1, value="x_j TERPAKAI (baris valid terakhir):").font = Font(bold=True)
ws.cell(row=LAST+3, column=1, value="dashboard:").font = Font(bold=True)
ws.cell(row=LAST+4, column=1, value="selisih:").font = Font(bold=True)
for k,c in enumerate(CODES):
    b=2+4*k; xc=CL(b+3)
    ws.cell(row=LAST+1, column=b+3, value=c).font=Font(bold=True)
    ws.cell(row=LAST+2, column=b+3, value=f'=LOOKUP(9.99E+307,{xc}{R0}:{xc}{LAST})').number_format="0.000000"
    ws.cell(row=LAST+3, column=b+3, value=float(shocks[f"t1_{c}"])).number_format="0.000000"
    ws.cell(row=LAST+4, column=b+3, value=f'={xc}{LAST+2}-{xc}{LAST+3}').number_format="0.00E+00"
ws.freeze_panes="B5"; ws.column_dimensions["A"].width=10
print("  01_shock_T1 selesai")

# ═══ 02_shock_T2 ═════════════════════════════════════════════════════════════
ws = wb.create_sheet("02_shock_T2")
title(ws, "Theme 2 — Shock Pertumbuhan Mitra Dagang",
          "d^g_c = WEO Apr2026 − Apr2025 (tahun 2026).   x_k = JUMLAH_c ( w_kc × d^g_c )")
cur = pd.read_csv(os.path.join(ROOT,"data","cache","theme2","vintages","weo_v202604.csv"))
pri = pd.read_csv(os.path.join(ROOT,"data","cache","theme2","vintages","weo_v202504.csv"))
c26 = cur[cur.year==2026].set_index("country")["ngdp_rpch"]
p26 = pri[pri.year==2026].set_index("country")["ngdp_rpch"]
dg  = pd.concat([c26.rename("curr"), p26.rename("prior")], axis=1).dropna()

ws["A4"]="BLOK A — revisi ramalan per negara"; ws["A4"].font=Font(bold=True,size=11)
header(ws,5,["negara","WEO Apr2026","WEO Apr2025","d^g_c (rumus)"])
for i,(iso,r) in enumerate(dg.iterrows()):
    x=6+i
    ws.cell(row=x,column=1,value=iso); ws.cell(row=x,column=2,value=float(r.curr))
    ws.cell(row=x,column=3,value=float(r.prior))
    ws.cell(row=x,column=4,value=f"=B{x}-C{x}").number_format="0.0000"
A_END=5+len(dg)

w = pd.read_csv(os.path.join(ROOT,"data","cache","theme2","export_weights_52_2023.csv"))
K = [2,3,6,7,8,9,10,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27]
w = w[w.sector_52.isin(K)].reset_index(drop=True)
B0 = A_END+3
ws.cell(row=B0,column=1,value="BLOK B — bobot ekspor × revisi").font=Font(bold=True,size=11)
header(ws,B0+1,["sector_52","sector_name","country_iso","w_kc","d^g_c (VLOOKUP)","w × d^g"])
for i,r in w.iterrows():
    x=B0+2+i
    ws.cell(row=x,column=1,value=int(r.sector_52)); ws.cell(row=x,column=2,value=r.sector_name)
    ws.cell(row=x,column=3,value=r.country_iso)
    ws.cell(row=x,column=4,value=float(r.w_kc)).number_format="0.000000"
    ws.cell(row=x,column=5,value=f'=IFERROR(VLOOKUP(C{x},$A$6:$D${A_END},4,FALSE),0)').number_format="0.0000"
    ws.cell(row=x,column=6,value=f"=D{x}*E{x}").number_format="0.000000"
B_S, B_E = B0+2, B0+1+len(w)
C0 = B_E+3
ws.cell(row=C0,column=1,value="BLOK C — x_k per sektor (SUMIF atas Blok B)").font=Font(bold=True,size=11)
header(ws,C0+1,["sector_52","sector_name","x_k (manual)","dashboard","selisih"])
nm = w.drop_duplicates("sector_52").set_index("sector_52")["sector_name"]
for i,s in enumerate(sorted(w.sector_52.unique())):
    x=C0+2+i
    ws.cell(row=x,column=1,value=int(s)); ws.cell(row=x,column=2,value=nm[s])
    ws.cell(row=x,column=3,value=f'=SUMIF($A${B_S}:$A${B_E},A{x},$F${B_S}:$F${B_E})').number_format="0.000000"
    ws.cell(row=x,column=4,value=float(shocks[f"t2_{nm[s]}"])).number_format="0.000000"
    ws.cell(row=x,column=5,value=f"=C{x}-D{x}").number_format="0.00E+00"
for col,wd in zip("ABCDEF",[11,16,12,12,14,13]): ws.column_dimensions[col].width=wd
print("  02_shock_T2 selesai")

# ═══ 03_shock_T3 ═════════════════════════════════════════════════════════════
ws = wb.create_sheet("03_shock_T3")
title(ws, "Theme 3 — Shock Permintaan Domestik",
          "x_i = g_yoy(t) − rata-rata 48 periode g_yoy (lag 1).  Sumber: BI Survei Penjualan Eceran")
sp = pd.read_csv(os.path.join(ROOT,"data","cache","theme3","spe_yoy_panel.csv"))
sp["date"]=pd.to_datetime(dict(year=sp.year,month=sp.month,day=1))
sp=(sp.sort_values(["category_code","date"])
      .drop_duplicates(subset=["category_code","date"],keep="last").reset_index(drop=True))
ws["A4"]="Panel sudah dideduplikasi (ambil baris terakhir per kategori+bulan) — lihat 12_catatan G3"
ws["A4"].font=Font(italic=True,size=9,color="C00000")
header(ws,5,["kategori","tanggal","g_yoy","tren48 (rumus)","x_i (rumus)"])
r=6; blocks={}
for cat,g in sp.groupby("category_code"):
    g=g.sort_values("date").reset_index(drop=True); st=r
    for _,row in g.iterrows():
        ws.cell(row=r,column=1,value=cat)
        ws.cell(row=r,column=2,value=row["date"].strftime("%Y-%m"))
        ws.cell(row=r,column=3,value=float(row.yoy_growth)).number_format="0.0000"
        if r-st>=48:
            ws.cell(row=r,column=4,value=f"=AVERAGE(C{r-48}:C{r-1})").number_format="0.0000"
            ws.cell(row=r,column=5,value=f"=C{r}-D{r}").number_format="0.0000"
        r+=1
    blocks[cat]=(st,r-1)
S0=r+2
ws.cell(row=S0,column=1,value="RINGKASAN x_i (nilai valid terakhir per kategori)").font=Font(bold=True,size=11)
header(ws,S0+1,["kategori","x_i (manual)","dashboard","selisih"])
for i,(cat,(st,en)) in enumerate(sorted(blocks.items())):
    x=S0+2+i
    ws.cell(row=x,column=1,value=cat)
    ws.cell(row=x,column=2,value=f'=LOOKUP(9.99E+307,E{st}:E{en})').number_format="0.000000"
    d=shocks.get(f"t3_{cat}")
    ws.cell(row=x,column=3,value=(float(d) if d is not None else "(tidak dipakai)")).number_format="0.000000"
    ws.cell(row=x,column=4,value=f'=IF(ISNUMBER(C{x}),B{x}-C{x},"")').number_format="0.00E+00"
for col,wd in zip("ABCDE",[20,11,12,15,14]): ws.column_dimensions[col].width=wd
ws.freeze_panes="A6"
print("  03_shock_T3 selesai")

# ═══ matriks 52x34 ═══════════════════════════════════════════════════════════
def matrix_sheet(name, ttl, sub, filler, numfmt="0.000000"):
    w_ = wb.create_sheet(name); title(w_, ttl, sub)
    header(w_, 4, ["sektor"]+PROV)
    for i in range(NS):
        r=5+i
        c=w_.cell(row=r,column=1,value=SECT[i]); c.fill=S_FILL; c.font=Font(bold=True,size=9)
        for j in range(NP):
            w_.cell(row=r,column=2+j,value=filler(i,j,r,CL(2+j))).number_format=numfmt
    w_.freeze_panes="B5"; w_.column_dimensions["A"].width=20
    for j in range(NP): w_.column_dimensions[CL(2+j)].width=11
    return w_

matrix_sheet("04_L0","Tenaga Kerja Awal L0","Sumber: rawdata/lo.csv (4 provinsi pemekaran Papua 2022 dikeluarkan)",
             lambda i,j,r,c: float(L0[i,j]), "#,##0")
matrix_sheet("05_shares","Pangsa Provinsi per Sektor","share[s,p] = L0[s,p] / total baris — setiap baris berjumlah 1",
             lambda i,j,r,c: f"=IF(SUM('04_L0'!$B{r}:${CL(1+NP)}{r})=0,0,'04_L0'!{c}{r}/SUM('04_L0'!$B{r}:${CL(1+NP)}{r}))")
print("  04_L0, 05_shares selesai")

# ═══ 06_intensity ════════════════════════════════════════════════════════════
ws = wb.create_sheet("06_intensity")
title(ws,"Tabel Intensitas 38 × 52","eta_j[s,p] = intensity_j[s] × share[s,p].  w[s] = JUMLAH_j ( x_j × intensity_j[s] )")
header(ws,4,["shock","x_j (pp)"]+SECT)
for i,k in enumerate(inten.index):
    r=5+i
    ws.cell(row=r,column=1,value=k).font=Font(bold=True,size=9)
    ws.cell(row=r,column=2,value=float(shocks[k])).number_format="0.000000"
    for j in range(NS):
        ws.cell(row=r,column=3+j,value=float(inten.iloc[i,j])).number_format="0.0000"
WR=5+NK
ws.cell(row=WR,column=1,value="w[s] =").font=Font(bold=True)
ws.cell(row=WR,column=2,value="SUMPRODUCT").font=Font(bold=True,italic=True)
for j in range(NS):
    c=CL(3+j)
    ws.cell(row=WR,column=3+j,
            value=f"=SUMPRODUCT($B$5:$B${4+NK},{c}5:{c}{4+NK})").number_format="0.000000"
    ws.cell(row=WR,column=3+j).fill=S_FILL
ws.freeze_panes="C5"; ws.column_dimensions["A"].width=20; ws.column_dimensions["B"].width=11
print("  06_intensity selesai")

# ═══ 07 / 08 / 09 / 10 ═══════════════════════════════════════════════════════
matrix_sheet("07_E_manual","E Manual — % Perubahan Tenaga Kerja",
             "E[s,p] = share[s,p] × w[s].   w[s] diambil dari baris SUMPRODUCT di 06_intensity",
             lambda i,j,r,c: f"='05_shares'!{c}{r}*INDEX('06_intensity'!$C${WR}:${CL(2+NS)}${WR},1,{i+1})")
matrix_sheet("08_dL_manual","dL Manual — Perubahan Jumlah Pekerja",
             "dL[s,p] = E[s,p] / 100 × L0[s,p]",
             lambda i,j,r,c: f"='07_E_manual'!{c}{r}/100*'04_L0'!{c}{r}", "#,##0.00")
matrix_sheet("09_dash_E","E dari Dashboard","Sumber: data/output/E_matrix.npy — pembanding",
             lambda i,j,r,c: float(E_dash[i,j]))
matrix_sheet("10_dash_dL","dL dari Dashboard","Sumber: data/output/dL_matrix.npy — pembanding",
             lambda i,j,r,c: float(dL_dash[i,j]), "#,##0.00")
print("  07-10 selesai")

# ═══ 11_selisih ══════════════════════════════════════════════════════════════
ws = wb.create_sheet("11_selisih")
title(ws,"Perbandingan — Manual vs Dashboard","Selisih per sel. Toleransi 1e-9. Hijau = cocok.")
ws["A4"]="RINGKASAN"; ws["A4"].font=Font(bold=True,size=12)
ER, DR = 12, 12+NS+4
summ=[("Selisih absolut maks — E",   f"=MAX(ABS(B{ER+1}:{CL(1+NP)}{ER+NS}))"),
      ("Selisih absolut maks — dL",  f"=MAX(ABS(B{DR+1}:{CL(1+NP)}{DR+NS}))"),
      ("Jumlah sel |selisih| > 1e-9 — E",  f"=COUNTIF(B{ER+1}:{CL(1+NP)}{ER+NS},\">1E-09\")+COUNTIF(B{ER+1}:{CL(1+NP)}{ER+NS},\"<-1E-09\")"),
      ("Jumlah sel |selisih| > 1e-9 — dL", f"=COUNTIF(B{DR+1}:{CL(1+NP)}{DR+NS},\">1E-09\")+COUNTIF(B{DR+1}:{CL(1+NP)}{DR+NS},\"<-1E-09\")"),
      ("Total sel diperiksa", NS*NP),
      ("Total dL manual", f"=SUM('08_dL_manual'!B5:{CL(1+NP)}{4+NS})"),
      ("Total dL dashboard", f"=SUM('10_dash_dL'!B5:{CL(1+NP)}{4+NS})")]
for i,(lab,f) in enumerate(summ):
    r=5+i
    ws.cell(row=r,column=1,value=lab).font=Font(bold=True)
    c=ws.cell(row=r,column=2,value=f)
    c.number_format="#,##0.00" if "Total" in lab else ("0" if "Jumlah" in lab else "0.00E+00")
    c.fill=OK_F
ws.column_dimensions["A"].width=34; ws.column_dimensions["B"].width=18

for lbl,base,src_m,src_d in [("SELISIH E  (manual − dashboard)",ER,"07_E_manual","09_dash_E"),
                             ("SELISIH dL (manual − dashboard)",DR,"08_dL_manual","10_dash_dL")]:
    ws.cell(row=base-1,column=1,value=lbl).font=Font(bold=True,size=11)
    header(ws,base,["sektor"]+PROV)
    for i in range(NS):
        r=base+1+i
        c=ws.cell(row=r,column=1,value=SECT[i]); c.fill=S_FILL; c.font=Font(bold=True,size=9)
        for j in range(NP):
            cl=CL(2+j)
            ws.cell(row=r,column=2+j,
                    value=f"='{src_m}'!{cl}{5+i}-'{src_d}'!{cl}{5+i}").number_format="0.00E+00"
    rng=f"B{base+1}:{CL(1+NP)}{base+NS}"
    ws.conditional_formatting.add(rng, ColorScaleRule(
        start_type="num", start_value=-1e-9, start_color="FFC7CE",
        mid_type="num",   mid_value=0,       mid_color="C6EFCE",
        end_type="num",   end_value=1e-9,    end_color="FFC7CE"))
ws.freeze_panes="B13"; ws.column_dimensions["A"].width=34
print("  11_selisih selesai")

# ═══ 12_catatan ══════════════════════════════════════════════════════════════
ws = wb.create_sheet("12_catatan")
title(ws,"Catatan dan Temuan","Rincian lengkap: audit/FINDINGS.md")
notes=[("A. HASIL VERIFIKASI ARITMATIKA",""),
 ("Theme 1 — 7 shock","Cocok persis, selisih 0,0e+00"),
 ("Theme 2 — 23 shock","Cocok persis, selisih maks 1,1e-16"),
 ("Theme 3 — 8 shock","Cocok persis, selisih 0,0e+00"),
 ("Matriks E dan dL 52x34","Cocok persis, selisih maks 2,7e-15 (E) dan 1,8e-11 (dL)"),
 ("KESIMPULAN","Tidak ditemukan kesalahan aritmatika di seluruh pipeline."),
 ("",""),
 ("B. BUG PADA DATA YANG MASUK",""),
 ("F2 — Taiwan hilang (T2)","Comtrade memakai kode S19, IMF memakai TWN. .fillna(0) membuang revisi +2,701pp. Taiwan ada di 22 dari 23 sektor. Shock Coal berubah +58%, WoodProd +121%."),
 ("G2 — Jun-Sep hilang (T3)","Sejak 2023 hanya 8 dari 12 bulan terbaca. Daftar nama bulan dipatok keras tidak cocok dengan format BI. Akibatnya jendela tren jadi 5,2 tahun, bukan 4 tahun."),
 ("G3 — dedup salah kolom (T3)","keep='last' memilih nilai yang tidak konsisten dengan deret. ict_equipment melompat dari -26,4 ke +8,9. Mengubah hasil akhir 52.900 pekerja (10,2%)."),
 ("",""),
 ("C. KEBARUAN DATA (permintaan #3)",""),
 ("I1 — deteksi Pink Sheet gagal total","URL World Bank TIDAK berubah saat file diperbarui. Kode hanya membandingkan URL, jadi selamanya melaporkan 'tidak ada update'. Data 2026M06 dan 2026M07 terlewat."),
 ("I2 — parser tidak bisa baca format baru","File sekarang tidak punya header 'Period'. _parse_pinksheet akan melempar ValueError."),
 ("I3 — DAMPAK","Dashboard terlalu tinggi 33,7%: +520.433 vs +344.865 pekerja dengan data terkini. Shock minyak runtuh dari +61,12 ke +17,44 pp."),
 ("",""),
 ("D. MASALAH METODOLOGI",""),
 ("B1 — skala tema tidak sebanding","Rata-rata shock T1 91x lebih besar dari T2. T1 menyumbang 92% hasil. Akibat perbedaan satuan, bukan ekonomi."),
 ("B2 — tidak ada sel negatif","Dari 1.605 sel berpenduduk, SEMUANYA positif. Dashboard PHK memprediksi pertambahan kerja di mana-mana."),
 ("E1 — placeholder menyimpang dari instruksi","Prompt meminta 1 sektor per shock, sisanya nol. Yang dibangun menambah spillover ke semua 52 sektor: 91,4% tensor, 61% hasil akhir."),
 ("",""),
 ("E. CATATAN PENTING",""),
 ("","Elastisitas masih PLACEHOLDER, bukan hasil IndoTERM. Kecocokan angka hanya"),
 ("","membuktikan aritmatika kode benar, BUKAN bahwa ekonominya benar.")]
for i,(a,b) in enumerate(notes,start=4):
    ws.cell(row=i,column=1,value=a).font=Font(bold=(b=="" and a!=""),size=10)
    c=ws.cell(row=i,column=2,value=b); c.alignment=Alignment(wrap_text=True,vertical="top")
ws.column_dimensions["A"].width=34; ws.column_dimensions["B"].width=95

wb.save(OUT)
print(f"\nTersimpan: {OUT}  ({os.path.getsize(OUT)/1024:.0f} KB, {len(wb.sheetnames)} sheet)")
