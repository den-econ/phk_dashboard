"""
01_build_baseline_master.py
One-time baseline merge for the PHK Early Warning Dashboard.
Owner: Muthia.

Reads the two raw workbooks, standardizes provinces, builds a province-month
panel, broadcasts annual and quarterly indicators across months, joins MAP
structural indicators with a 2024-into-2025 carry-forward, and writes:
  clean_data/phk_master.csv        curated province-month panel
  clean_data/annual_full.csv       full annual sheet, tidy
  clean_data/map_kabkot_context.csv MAP kabupaten and kota rows, kept separate
  technical_notes/baseline_merge_notes.md   assumptions and row counts

Run from the repo root:  python code/01_build_baseline_master.py
"""
from __future__ import annotations
from pathlib import Path
import pandas as pd

import utils

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "raw_data"
CLEAN = ROOT / "clean_data"
CFG = ROOT / "config"
NOTES = ROOT / "technical_notes" / "baseline_merge_notes.md"

PHK_FILE = RAW / "Data untuk PHK Dashboard.xlsx"
MAP_FILE = RAW / "MAP_composite_all.xlsx"
GEOJSON = RAW / "geospatial" / "indonesia_38_provinces.geojson"

YEARS = [2022, 2023, 2024, 2025]
MONTHS = list(range(1, 13))
DATA_VERSION = "baseline-v1"


def main():
    admin = utils.load_yaml(CFG / "admin_mapping.yml")
    schema = utils.load_yaml(CFG / "master_schema.yml")
    standardize = utils.build_province_standardizer(admin)
    matched_provinces = set(admin["aliases"].values())
    new_no_map = set(admin["new_provinces_no_map"])
    canon = admin["canonical_provinces"]

    notes = []

    def log(msg):
        print(msg)
        notes.append(msg)

    log(f"# Baseline merge notes ({utils.today_iso()})\n")
    log(f"Data version: {DATA_VERSION}\n")

    # ---- province code map ----
    codes = utils.geojson_province_codes(GEOJSON, standardize)
    missing_codes = [p for p in canon if p not in codes]
    log(f"Province codes resolved from GeoJSON: {len(codes)} of {len(canon)}")
    if missing_codes:
        log(f"Provinces without a code (left blank): {missing_codes}")

    # ---- skeleton: 38 provinces x 48 months ----
    skel = pd.MultiIndex.from_product([canon, YEARS, MONTHS],
                                      names=["province_std", "year", "month"]).to_frame(index=False)
    skel["quarter"] = skel["month"].map(utils.month_to_quarter)
    skel["date"] = pd.to_datetime(dict(year=skel.year, month=skel.month, day=1)).dt.strftime("%Y-%m-%d")
    skel["province_code"] = skel["province_std"].map(codes).fillna("")
    log(f"\nSkeleton rows: {len(skel)} (expected {len(canon) * len(YEARS) * len(MONTHS)})")

    # ---- monthly (Database Bulan) ----
    bul = utils.read_excel_clean(PHK_FILE, "Database (Bulan)")
    bul["province_std"] = bul["Provinsi"].apply(standardize)
    bul = bul.rename(columns={"Tahun": "year", "Bulan": "month"})
    mmap = {**schema["monthly_provincial"], **schema["monthly_national"]}
    keep = ["province_std", "year", "month"] + [c for c in mmap if c in bul.columns]
    bulk = bul[keep].rename(columns=mmap)
    master = skel.merge(bulk, on=["province_std", "year", "month"], how="left")
    log(f"Monthly indicators merged: {list(mmap.values())}")

    # period-level PHK reporting count (same for all provinces in a year-month)
    rep = (bul.assign(has=bul["PHK (Flow)"].notna())
              .groupby(["year", "month"])["has"].sum().rename("phk_period_reporting_count"))
    master = master.merge(rep, on=["year", "month"], how="left")
    master["phk_period_reporting_count"] = master["phk_period_reporting_count"].fillna(0).astype(int)

    # ---- annual (Database Tahun), broadcast across 12 months ----
    tah = utils.read_excel_clean(PHK_FILE, "Database (Tahun)")
    tah["province_std"] = tah["Provinsi"].apply(standardize)
    tah = tah.rename(columns={"Tahun": "year"})
    amap = schema["annual_repeated"]
    acols = ["province_std", "year"] + [c for c in amap if c in tah.columns]
    annual = tah[acols].rename(columns=amap)
    master = master.merge(annual, on=["province_std", "year"], how="left")
    master["annual_indicator_repeated_monthly"] = master[list(amap.values())].notna().any(axis=1)
    log(f"Annual indicators broadcast: {list(amap.values())}")

    # ---- quarterly (Database Triwulan), broadcast across 3 months ----
    tri = utils.read_excel_clean(PHK_FILE, "Database (Triwulan)")
    tri["province_std"] = tri["Provinsi"].apply(standardize)
    tri = tri.rename(columns={"Tahun": "year", "Triwulan": "quarter"})
    roman = {"I": 1, "II": 2, "III": 3, "IV": 4, "1": 1, "2": 2, "3": 3, "4": 4}
    tri["quarter"] = tri["quarter"].astype(str).str.strip().map(roman)
    tri = tri.dropna(subset=["quarter"])
    tri["quarter"] = tri["quarter"].astype(int)
    qmap = schema["quarterly_repeated"]
    qcols = ["province_std", "year", "quarter"] + [c for c in qmap if c in tri.columns]
    quarterly = tri[qcols].rename(columns=qmap)
    master = master.merge(quarterly, on=["province_std", "year", "quarter"], how="left")
    master["quarterly_indicator_repeated_monthly"] = master[list(qmap.values())].notna().any(axis=1)
    log(f"Quarterly indicators broadcast: {list(qmap.values())}")

    # ---- MAP province rows, join on province-year with 2024 -> 2025 carry-forward ----
    mp = pd.read_excel(MAP_FILE, header=1).dropna(how="all")
    mp.columns = utils.clean_column_names(mp.columns)
    mp = mp[mp["name"] == "Provinsi"].copy()
    mp["province_std"] = mp["id_label"].apply(standardize)
    map_latest = int(admin["map_carry_forward"]["latest_map_year"])
    carry_years = admin["map_carry_forward"]["apply_to_years"]

    mmap_map = schema["map_repeated"]
    mp_small = mp[["province_std", "year"] + [c for c in mmap_map if c in mp.columns]].rename(columns=mmap_map)

    # attach a map_year column: for carry years use the latest MAP year rows
    frames = []
    for y in YEARS:
        src_year = map_latest if y in carry_years else y
        block = mp_small[mp_small["year"] == src_year].copy()
        block["year"] = y
        block["map_year_used"] = src_year
        frames.append(block)
    map_join = pd.concat(frames, ignore_index=True)
    master = master.merge(map_join, on=["province_std", "year"], how="left")
    log(f"MAP structural indicators joined: {[v for v in mmap_map.values()]}")
    log(f"MAP carry-forward: year(s) {carry_years} use MAP {map_latest}")

    # ---- status flags ----
    master["admin_mapping_status"] = master["province_std"].apply(
        lambda p: "new_province_no_map" if p in new_no_map else "matched")
    # map_year_used: integer year where MAP data was used, blank otherwise
    master["map_year_used"] = master["map_year_used"].astype("Int64").astype(str).replace("<NA>", "")
    master.loc[master["province_std"].isin(new_no_map), "map_year_used"] = ""

    has_phk = master[["phk_stock", "phk_flow"]].notna().any(axis=1)
    master["phk_reporting_status"] = has_phk.map({True: "reported", False: "no_data"})

    # ---- provenance ----
    master["province_name_original"] = master["province_std"]
    master["baseline_merge_source"] = "Database Bulan + Tahun + Triwulan + MAP"
    master["data_version"] = DATA_VERSION
    master["last_updated"] = utils.today_iso()
    master["source_file"] = "Data untuk PHK Dashboard.xlsx; MAP_composite_all.xlsx"

    # ---- column order ----
    ordered = (schema["identity"]
               + list(schema["monthly_provincial"].values())
               + list(schema["monthly_national"].values())
               + ["phk_period_reporting_count"]
               + list(schema["annual_repeated"].values())
               + list(schema["quarterly_repeated"].values())
               + [v for v in schema["map_repeated"].values()]
               + schema["flags"] + schema["provenance"])
    ordered = [c for c in ordered if c in master.columns]
    master = master[ordered].sort_values(["province_std", "year", "month"]).reset_index(drop=True)

    CLEAN.mkdir(parents=True, exist_ok=True)
    master.to_csv(CLEAN / "phk_master.csv", index=False)
    log(f"\nphk_master.csv written: {master.shape[0]} rows x {master.shape[1]} cols")

    # ---- annual_full.csv (full annual sheet, tidy) ----
    annual_full = tah.copy()
    annual_full.to_csv(CLEAN / "annual_full.csv", index=False)
    log(f"annual_full.csv written: {annual_full.shape[0]} rows x {annual_full.shape[1]} cols")

    # ---- map_kabkot_context.csv (MAP kabupaten and kota) ----
    mp_all = pd.read_excel(MAP_FILE, header=1).dropna(how="all")
    mp_all.columns = utils.clean_column_names(mp_all.columns)
    kabkot = mp_all[mp_all["name"] == "Kabkot"].copy()
    kabkot.to_csv(CLEAN / "map_kabkot_context.csv", index=False)
    log(f"map_kabkot_context.csv written: {kabkot.shape[0]} rows")

    # ---- key check ----
    dups = utils.validate_keys(master, ["province_std", "year", "month"])
    log(f"\nDuplicate province-month keys: {len(dups)} (should be 0)")

    # ---- quick coverage summary ----
    log("\n## Coverage")
    log(f"- Provinces: {master['province_std'].nunique()}")
    log(f"- Months: {master['date'].nunique()}")
    log(f"- Rows with PHK flow reported: {master['phk_flow'].notna().sum()}")
    log(f"- Rows flagged new_province_no_map: {(master['admin_mapping_status']=='new_province_no_map').sum()}")
    log(f"- Rows using carried-forward MAP (2025): {((master['year'] == 2025) & (master['map_year_used'] != '')).sum()}")

    NOTES.parent.mkdir(parents=True, exist_ok=True)
    NOTES.write_text("\n".join(notes), encoding="utf-8")
    print(f"\nNotes written to {NOTES}")


if __name__ == "__main__":
    main()
