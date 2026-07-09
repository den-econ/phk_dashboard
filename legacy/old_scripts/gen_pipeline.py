"""
gen_pipeline.py — generate the Stata build (.do) and master_schema.yml from the
finalized crosswalk in data/processed/indicator_dictionary.csv.

Pipeline of generators (run from repo ROOT, in order, after any workbook change):
  python code/build_crosswalk.py     # workbook -> indicator_dictionary.csv (names, classification)
  python code/gen_pipeline.py        # dictionary -> master_schema.yml + 01_build_baseline_master.do

The .do renames columns by Excel position, so it must be regenerated whenever the
workbook columns change. Requires: openpyxl, pyyaml.
"""
import csv, re
from collections import defaultdict, OrderedDict
from openpyxl import load_workbook

PHKX='data/raw_data/Data untuk PHK Dashboard.xlsx'
MAPX='data/raw_data/MAP_composite_all.xlsx'
DICT='data/processed/indicator_dictionary.csv'

def norm(s): return re.sub(r'\s+',' ', str(s).replace('\n',' ')).strip()
def xlcol(i):
    s=""; i+=1
    while i: i,r=divmod(i-1,26); s=chr(65+r)+s
    return s

# ---- read the crosswalk ----
X=defaultdict(dict)   # sheet -> {orig_header: rowdict}
for r in csv.DictReader(open(DICT)):
    X[r['source_sheet']][r['original_column_name']]=r

# unified pairs (shortened names), written by build_crosswalk.py
UNIFY=list(csv.DictReader(open('data/processed/_unify_pairs.csv')))
UMP_COL=[u for u in UNIFY if u['phk_col'].startswith('wage_ump')][0]['phk_col']
UNIFY_CALLS="\n".join(f"unify_map {u['phk_col']} {u['map_col']} {u['source_flag']}" for u in UNIFY)
UNIFY_SRC_FLAGS="\n".join(f"  - {u['source_flag']}" for u in UNIFY)

# ---- read workbook headers WITH position ----
def headers_idx(path, sheet, hdr_row=1):
    wb=load_workbook(path, read_only=True, data_only=True); ws=wb[sheet]
    it=ws.iter_rows(values_only=True)
    for _ in range(hdr_row-1): next(it)
    row=next(it)
    return [(i, norm(c)) for i,c in enumerate(row) if c is not None and norm(c)!='']

SHEETS={
 'Database (Bulan)':    headers_idx(PHKX,'Database (Bulan)'),
 'Database (Triwulan)': headers_idx(PHKX,'Database (Triwulan)'),
 'Database (Tahun)':    headers_idx(PHKX,'Database (Tahun)'),
 'MAP':                 headers_idx(MAPX,'Sheet 1 - MAP_composite_all', hdr_row=2),
}
STRING={'province_name','province_name_std','date','quarter_end_month_label',
        'region_name','region_level','map_threshold_status_annual','map_quantile_status_annual'}

def final_of(sheet,h):
    return X[sheet][h]['final_column_name']
def is_natl(sheet,h):
    return X[sheet].get(h,{}).get('national_repeated','')=='yes'
def in_master(sheet,h):
    return X[sheet].get(h,{}).get('include_in_master','').startswith('yes')

# ---- build per-sheet ordered column info ----
def cols(sheet, drop_headers=()):
    out=[]
    for i,h in SHEETS[sheet]:
        if h in drop_headers: continue
        out.append((xlcol(i), h, final_of(sheet,h)))
    return out
BUL=cols('Database (Bulan)', drop_headers={'Periode'})   # date reconstructed from year+month
TRI=cols('Database (Triwulan)')
TAH=cols('Database (Tahun)')
MAPC=cols('MAP')

def natl_names(sheet):
    return [final_of(sheet,h) for _i,h in SHEETS[sheet] if is_natl(sheet,h)]
NM=natl_names('Database (Bulan)'); NQ=natl_names('Database (Triwulan)'); NY=natl_names('Database (Tahun)')

def master_names(sheet, extra_drop=()):
    out=[]
    for _i,h in SHEETS[sheet]:
        fn=final_of(sheet,h)
        if fn in extra_drop: continue
        if is_natl(sheet,h): continue
        if fn in ('province_name','year','month','quarter','date','quarter_end_month_label'): continue
        if in_master(sheet,h): out.append(fn)
    return out
MBUL=master_names('Database (Bulan)')
MTRI=master_names('Database (Triwulan)', extra_drop={'quarter_end_month_label'})
MTAH=master_names('Database (Tahun)')
MAP_PROV=[final_of('MAP',h) for _i,h in SHEETS['MAP']
          if final_of('MAP',h) not in ('region_level','region_id','region_name','year')]

def wrap(tokens, indent="        ", width=10):
    t=tokens if isinstance(tokens,list) else tokens.split()
    return (" ///\n"+indent).join(" ".join(t[i:i+width]) for i in range(0,len(t),width)) if t else ""

def rename_stmt(colinfo, by_name=False):
    # one `rename old new` per line (robust; avoids the grouped-rename + /// parser bug).
    # by_name=True renames by the original header (for firstrow imports like MAP);
    # otherwise renames by Excel column letter (for headerless imports).
    lines=[]
    for c in colinfo:
        old=c[1] if by_name else c[0]
        if old==c[2]: continue           # skip no-op (e.g. year -> year)
        lines.append(f"rename {old} {c[2]}")
    return "\n".join(lines)
def keep_stmt(names):
    return "keep "+wrap(names,"     ")

# ---------- assemble the .do ----------
def phk_sheet(title, num, sheet_name, colinfo, freq, period_by, natl, master_cols,
              feat_file, string_present, quarter=False, harmonize=""):
    natl_kv = " ".join(natl)
    s=[f"""*==============================================================
* {num}. {title}
*==============================================================
import excel using "$PHK", sheet("{sheet_name}") clear
{rename_stmt(colinfo)}
{keep_stmt([c[2] for c in colinfo])}
drop in 1
replace province_name = strtrim(province_name)"""]
    if quarter:
        s.append("""gen _q = .
replace _q = 1 if inlist(strtrim(quarter),"I","1")
replace _q = 2 if inlist(strtrim(quarter),"II","2")
replace _q = 3 if inlist(strtrim(quarter),"III","3")
replace _q = 4 if inlist(strtrim(quarter),"IV","4")
drop quarter
rename _q quarter""")
    s.append(f"ds {string_present}, not\ndestring `r(varlist)', replace force")
    s.append("drop if missing(year)                 // drop blank / footer rows")
    s.append('gen province_name_std = strtrim(province_name)')
    s.append('drop if province_name_std == ""')
    if harmonize: s.append(harmonize)
    # feature file (native grain, full set)
    s.append(f'order province_name_std, first\nexport delimited using "$PROC/{feat_file}", replace')
    # national extraction
    if natl:
        s.append(f"""preserve
    keep year {period_by if period_by!='year' else ''} {natl_kv}
    collapse (mean) {natl_kv}, by(year {period_by if period_by!='year' else ''})
    sort year {period_by if period_by!='year' else ''}
    export delimited using "$PROC/national_{freq}.csv", replace
restore""".replace("by(year )","by(year)").replace("keep year  ","keep year "))
    # master tempfile
    keycols = {'monthly':'province_name_std year month','quarterly':'province_name_std year quarter','annual':'province_name_std year'}[freq]
    s.append(f"keep {keycols} {wrap(master_cols,'     ')}\ntempfile {freq}\nsave `{freq}'")
    return "\n".join(s)

DO=[]
DO.append("""*==============================================================
* 01_build_baseline_master.do   (domain-named build)
* Province-month master + native-grain feature files + national files.
* Generated by code/gen_pipeline.py from data/processed/indicator_dictionary.csv.
* Columns are renamed by Excel POSITION -> regenerate after any workbook change.
* Naming: domain prefixes (phk_/lab_/wage_/macro_/price_/trade_/fin_/bpjstk_/
*   emp_/emp_share_/ind_/map_/growth_/lag1_/diff_); source lives in src_* + dict.
* Requires Stata 14+. Run from the repo root:  do code/01_build_baseline_master.do
*==============================================================
version 14
clear all
set more off

global REPO   "."
global RAW    "$REPO/data/raw_data"
global PROC   "$REPO/data/processed"
global NOTES  "$REPO/technical_notes/baseline_merge_notes.md"
global PHK    "$RAW/Data untuk PHK Dashboard.xlsx"
global MAP    "$RAW/MAP_composite_all.xlsx"
global MAPSHT "Sheet 1 - MAP_composite_all"
capture mkdir "$PROC"
capture mkdir "$REPO/technical_notes"

*==============================================================
* 0. Calendar skeleton: 2014-01 .. 2025-12 (144 months)
*==============================================================
clear
set obs 144
gen long i = _n
gen year    = 2014 + floor((i-1)/12)
gen month   = mod(i-1,12) + 1
gen quarter = floor((month-1)/3) + 1
drop i
tempfile yearmonth
save `yearmonth'""")

DO.append(phk_sheet("Monthly sheet (Database Bulan)", 1, "Database (Bulan)", BUL,
                    "monthly","month", NM, MBUL, "phk_monthly_features.csv", "province_name"))
DO.append(phk_sheet("Annual sheet (Database Tahun)", 2, "Database (Tahun)", TAH,
                    "annual","year", NY, MTAH, "phk_annual_features.csv", "province_name",
                    harmonize=f"""* unit harmonization so values match their _pct / _idr column names
*   (PHK stores sector shares as fractions and UMP in thousand-IDR; MAP uses percent / IDR)
foreach v of varlist emp_share_* {{
    replace `v' = `v'*100
}}
replace {UMP_COL} = {UMP_COL}*1000"""))
DO.append(phk_sheet("Quarterly sheet (Database Triwulan)", 3, "Database (Triwulan)", TRI,
                    "quarterly","quarter", NQ, MTRI, "phk_quarterly_features.csv",
                    "province_name quarter_end_month_label quarter", quarter=True))

# MAP section
map_rename=rename_stmt(MAPC, by_name=True)
DO.append(f"""*==============================================================
* 4. MAP composite. NOTE: in the source, `name` = level (Provinsi/Kabkot) and
*    `id_label` = region name -> mapped to region_level / region_name.
*==============================================================
import excel using "$MAP", sheet("$MAPSHT") cellrange(A2) firstrow case(preserve) clear
{map_rename}
keep {wrap([c[2] for c in MAPC],'     ')}
* kabkot context (non-province rows) -> separate feature file
preserve
    keep if region_level=="Kabkot"
    export delimited using "$PROC/map_kabkot_context.csv", replace
restore
keep if region_level=="Provinsi"
keep if year>=2014 & year<=2024
gen province_name_std = proper(region_name)
replace province_name_std = "DKI Jakarta"     if upper(region_name)=="DKI JAKARTA"
replace province_name_std = "DI Yogyakarta"   if upper(region_name)=="DI YOGYAKARTA"
replace province_name_std = "Bangka Belitung" if upper(region_name)=="KEPULAUAN BANGKA BELITUNG"
gen region_code = string(floor(region_id/100),"%02.0f")
keep province_name_std year {wrap(MAP_PROV,'     ')}
gen map_year_used = year
preserve
    keep if year==2024
    replace year = 2025
    tempfile map2025
    save `map2025'
restore
append using `map2025'
tempfile mapprov
save `mapprov'""")

# master build
DO.append(f"""*==============================================================
* 5. Build the province-month master (2014-2025) and merge everything on.
*    National columns already went to national_*.csv and are NOT merged here.
*==============================================================
use `monthly', clear
keep province_name_std
duplicates drop
cross using `yearmonth'
gen date = string(year) + "-" + string(month,"%02.0f") + "-01"
merge 1:1 province_name_std year month using `monthly',    keep(master match) nogen
merge m:1 province_name_std year        using `annual',     keep(master match) gen(_m_annual)
merge m:1 province_name_std year quarter using `quarterly', keep(master match) gen(_m_quarterly)
merge m:1 province_name_std year        using `mapprov',    keep(master match) gen(_m_map)

*==============================================================
* 5b. Unify overlapping PHK/MAP indicators into single columns.
*     PHK value where available; MAP backfills 2014-2021 (same unit after the
*     harmonization in section 2); *_source flags the origin. The MAP twin is
*     then dropped. Verified on 2022-2024 overlap: informal/PDRB/sector-shares
*     corr 1.00, TPT 0.95, UMP 0.88.
*==============================================================
capture program drop unify_map
program define unify_map
    args tgt mv src
    gen byte _had = !missing(`tgt')
    replace `tgt' = `mv' if missing(`tgt') & !missing(`mv')
    gen str3 `src' = ""
    replace `src' = "PHK" if _had
    replace `src' = "MAP" if !_had & !missing(`tgt')
    drop _had `mv'
end
{UNIFY_CALLS}
capture program drop unify_map

*==============================================================
* 6. Flags and provenance
*==============================================================
gen byte flag_annual_repeated_monthly    = _m_annual==3
gen byte flag_quarterly_repeated_monthly = _m_quarterly==3
gen byte flag_national_repeated_province = 0   // national kept in separate files
drop _m_annual _m_quarterly _m_map
gen byte flag_admin_mapping_review = inlist(province_name_std,"Papua Selatan","Papua Tengah","Papua Pegunungan","Papua Barat Daya")
gen byte flag_merge_issue = 0
gen byte flag_manual_review_required = 0
gen src_file            = "Data untuk PHK Dashboard.xlsx; MAP_composite_all.xlsx"
gen src_sheet           = "Database (Bulan)+(Triwulan)+(Tahun) + MAP_composite_all"
gen src_last_updated    = string(date(c(current_date),"DMY"), "%tdCCYY!-NN!-DD")
gen src_data_version    = "v3-domain-named"
gen src_update_batch_id = "baseline"

*==============================================================
* 7. Order, checks, export master + merge_issues
*==============================================================
order province_name_std province_name year month date quarter, first
sort province_name_std year month
isid province_name_std year month
export delimited using "$PROC/phk_master.csv", replace

preserve
    keep if flag_admin_mapping_review==1
    keep province_name_std year month
    export delimited using "$PROC/merge_issues.csv", replace
restore

qui count
display as result "Done. phk_master rows: `r(N)' (expect 5472)."
""")

open('code/01_build_baseline_master.do','w').write("\n\n".join(DO))
print("wrote code/01_build_baseline_master.do")

# ---------- master_schema.yml ----------
allrows=list(csv.DictReader(open(DICT)))
DOM_ORDER=['phk','lab','wage','bpjstk','emp','emp_share','ind','growth','lag','diff','macro','price','trade','fin','map']
grp=defaultdict(list); natl=defaultdict(list)
for r in allrows:
    if r['include_in_master'].startswith('yes'): grp[r['domain']].append(r['final_column_name'])
    if r['national_repeated']=='yes': natl[r['frequency']].append(r['final_column_name'])
def yl(items, ind="    "): return "\n".join(f"{ind}- {c}" for c in items)
S=[f"""# ============================================================================
# PHK master dataset schema  (domain-based naming, finalized)
# Master:  data/processed/phk_master.csv   Grain: province x month (2014-01..2025-12)
# PK: province_name_std + year + month
#
# Naming: the COLUMN NAME says what the variable MEANS (domain prefix); WHERE it
# came from is metadata (src_* fields + indicator_dictionary.csv), NOT in the name.
# phk_* is reserved for actual layoff indicators. Complete source->final mapping
# for every column: data/processed/indicator_dictionary.csv (nothing dropped -
# each column is in master, in a feature file, or excluded_from_master + reason).
# ============================================================================
master_dataset: data/processed/phk_master.csv
grain: province-month
primary_key: [province_name_std, year, month]

identity: [province_name_std, province_name, year, month, date, quarter]
provenance_fields: [src_file, src_sheet, src_last_updated, src_data_version, src_update_batch_id]
flags:
  - flag_annual_repeated_monthly
  - flag_quarterly_repeated_monthly
  - flag_national_repeated_province
  - flag_admin_mapping_review
  - flag_merge_issue
  - flag_manual_review_required

# origin ("PHK"/"MAP") of each unified column (PHK + MAP backfill for 2014-2021)
unified_source_flags:
{UNIFY_SRC_FLAGS}

master_columns:"""]
for d in DOM_ORDER:
    if grp.get(d): S.append(f"  {d}:\n{yl(grp[d])}")
S.append("""
feature_files:
  data/processed/phk_monthly_features.csv:   {grain: province-month,   source_sheet: Database (Bulan)}
  data/processed/phk_quarterly_features.csv: {grain: province-quarter, source_sheet: Database (Triwulan)}
  data/processed/phk_annual_features.csv:    {grain: province-year,    source_sheet: Database (Tahun)}
  data/processed/map_kabkot_context.csv:     {grain: kabupaten/kota,   source: MAP kabkot rows}
  data/processed/indicator_dictionary.csv:   {complete source-to-final mapping + metadata}
  data/processed/merge_issues.csv:           {province-years failing key/mapping checks}

national_files:""")
for freq,fn in [('monthly','national_monthly.csv'),('quarterly','national_quarterly.csv'),('annual','national_annual.csv')]:
    S.append(f"  data/processed/{fn}:\n{yl(natl.get(freq,[]))}")
S.append("""
excluded_from_master:
  - {source_sheet: phk, reason: raw wide province x date pivot of layoff Stock/Flow; tidy version already in Database (Bulan) as phk_stock / phk_flow}
  - {source_sheet: Kebutuhan Data, reason: requirements/metadata sheet (not data); used only to populate indicator_dictionary.csv}
""")
open('config/master_schema.yml','w').write("\n".join(S))
print("wrote config/master_schema.yml")
print(f"master indicators: monthly(direct)={len(MBUL)} annual={len(MTAH)} quarterly={len(MTRI)} map={len(MAP_PROV)}")
print(f"national: monthly={len(NM)} quarterly={len(NQ)} annual={len(NY)}")
