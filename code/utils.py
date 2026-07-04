"""
utils.py
Shared helpers for the PHK Early Warning Dashboard pipeline.
Owner: Muthia. Keep functions small and pure so they can be reused across
the merge, ingest, validate, and export scripts.
"""
from __future__ import annotations
import re
import json
import datetime as dt
from pathlib import Path

import pandas as pd
import yaml


def load_yaml(path: str | Path) -> dict:
    """Read a YAML config file into a dict."""
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def clean_column_names(cols) -> list[str]:
    """Strip whitespace and collapse internal newlines in column headers."""
    out = []
    for c in cols:
        c = str(c).replace("\n", " ").strip()
        c = re.sub(r"\s+", " ", c)
        out.append(c)
    return out


def read_excel_clean(path: str | Path, sheet: str, header: int = 0) -> pd.DataFrame:
    """Read an Excel sheet, drop fully empty rows, clean the headers."""
    df = pd.read_excel(path, sheet_name=sheet, header=header)
    df = df.dropna(how="all")
    df.columns = clean_column_names(df.columns)
    return df


def build_province_standardizer(admin_mapping: dict):
    """
    Return a function name -> canonical province name.
    Uses the alias table from admin_mapping.yml, falling back to a title-cased
    version of the input when no alias matches.
    """
    aliases = {str(k).strip().upper(): v for k, v in admin_mapping.get("aliases", {}).items()}
    canon = set(admin_mapping.get("canonical_provinces", []))

    def standardize(name: str) -> str:
        if name is None:
            return name
        s = str(name).strip()
        if s in canon:
            return s
        key = s.upper()
        if key in aliases:
            return aliases[key]
        # light fallback for casing only
        guess = s.title().replace("Di ", "DI ").replace("Dki ", "DKI ")
        return guess if guess in canon else s

    return standardize


def validate_keys(df: pd.DataFrame, keys: list[str]) -> pd.DataFrame:
    """Return the rows that share a duplicate composite key (empty if none)."""
    dup_mask = df.duplicated(subset=keys, keep=False)
    return df.loc[dup_mask, keys].sort_values(keys)


def month_to_quarter(month: int) -> int:
    """Map a calendar month (1..12) to its quarter (1..4)."""
    return (int(month) - 1) // 3 + 1


def write_log(path: str | Path, records: list[dict]) -> None:
    """Append a list of dict records to a CSV log, creating it if needed."""
    path = Path(path)
    new = pd.DataFrame(records)
    if path.exists():
        old = pd.read_csv(path)
        new = pd.concat([old, new], ignore_index=True)
    path.parent.mkdir(parents=True, exist_ok=True)
    new.to_csv(path, index=False)


def geojson_province_codes(path: str | Path, standardize) -> dict:
    """
    Build a {canonical_province: province_code} map from the 38-province GeoJSON.
    Looks for KODE_PROV and PROVINSI in feature properties.
    """
    with open(path, "r", encoding="utf-8") as f:
        gj = json.load(f)
    out = {}
    for feat in gj.get("features", []):
        props = feat.get("properties", {})
        code = props.get("KODE_PROV") or props.get("kode_prov")
        name = props.get("PROVINSI") or props.get("Provinsi") or props.get("provinsi")
        if code is not None and name is not None:
            out[standardize(name)] = str(code).zfill(2)
    return out


def today_iso() -> str:
    return dt.date.today().isoformat()
