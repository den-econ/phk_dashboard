"""Build dashboard_empdash_data.js — the Live Monitoring payload behind Tab 5.

Reads the empdash pipeline outputs (data/output/*.npy + aggregation_meta.json)
and re-publishes them as a browser-side JSON blob, so Tab 5 shows exactly the
matrices, shocks and vintages that the pipeline produced. Nothing is recomputed
here; run the pipeline first:

    cd <empdash>
    python -m pipeline.refresh
    python -c "from pipeline.refresh import run; from pipeline.aggregation import compute, decompose; \
               r = run(verbose=False); compute(r); decompose(r)"

then run this script, followed by build_empdash_sim_data.py.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd


SCRIPT_PATH = Path(__file__).resolve()
DASHBOARD_DIR = SCRIPT_PATH.parent.parent
REPO_EMPDASH = DASHBOARD_DIR.parent / "empdash"
LOCAL_EMPDASH = Path(r"C:\Users\timot\Documents\empdash")
ROOT = REPO_EMPDASH if REPO_EMPDASH.exists() else LOCAL_EMPDASH
OUT = DASHBOARD_DIR / "dashboard_empdash_data.js"

# Papua splits created in 2022 are not separate IndoTERM regions.
EXCLUDED_PROVINCE_IDS = [9200, 9500, 9600, 9700]
NATIONAL_ID = 9900

# dL matrix name in data/output -> key used by the dashboard
MATRIX_KEYS = {
    "overall": "overall",
    "t1_total": "t1",
    "t2_total": "t2",
    "t3_total": "t3",
    "e_overall": "e_overall",
    "e_t1_total": "e_t1",
    "e_t2_total": "e_t2",
    "e_t3_total": "e_t3",
}

PROVINCE_POLICY = (
    "The four 2022 Papua split provinces are excluded to match the "
    "IndoTERM 34-region matrices."
)
FORMULA = "E = sum_j(x_j * eta_j); dL = (E / 100) * L0"


# str.title() lower-cases these administrative prefixes; restore them.
ACRONYM_FIXES = {"Dki": "DKI", "Di": "DI"}


def _province_names(prov_order: list[int]) -> list[str]:
    lo = pd.read_csv(ROOT / "rawdata" / "lo.csv")
    labels = lo.drop_duplicates("id").set_index("id")["id_label"].str.title().to_dict()
    names = []
    for pid in prov_order:
        parts = str(labels.get(pid, pid)).split(" ")
        names.append(" ".join(ACRONYM_FIXES.get(p, p) for p in parts))
    return names


def main() -> None:
    out_dir = ROOT / "data" / "output"
    eta_meta = json.loads((ROOT / "data" / "elasticity" / "eta_meta.json").read_text(encoding="utf-8"))
    agg_meta = json.loads((out_dir / "aggregation_meta.json").read_text(encoding="utf-8"))

    prov_order = [p for p in eta_meta["province_order"]
                  if p not in EXCLUDED_PROVINCE_IDS and p != NATIONAL_ID]
    sect_order = list(eta_meta["sector_order"])

    matrices: dict[str, list[list[float]]] = {}
    for npy_name, key in MATRIX_KEYS.items():
        matrices[key] = np.load(out_dir / f"{npy_name}.npy").tolist()
    matrices["baseline"] = np.load(out_dir / "L0_matrix.npy").tolist()

    payload = {
        "meta": {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "pipeline_built_at": eta_meta.get("built_at"),
            "pipeline_source": eta_meta.get("source"),
            "elasticity_source": agg_meta.get(
                "elasticity_source",
                f"IndoTERM CGE, rebuilt {eta_meta.get('built_at')}",
            ),
            "periods": agg_meta.get("periods", {}),
            "province_count": len(prov_order),
            "sector_count": len(sect_order),
            "shock_count": len(agg_meta.get("shocks_used", {})),
            "formula": FORMULA,
            "province_policy": PROVINCE_POLICY,
        },
        "province_codes": prov_order,
        "province_names": _province_names(prov_order),
        "sector_codes": sect_order,
        "sector_names": list(eta_meta["sector_labels"]),
        "shocks": agg_meta.get("shocks_used", {}),
        "matrices": matrices,
    }

    OUT.write_text(
        "window.PHK_EMPDASH_DATA=" + json.dumps(payload, separators=(",", ":")) + ";\n",
        encoding="utf-8",
    )
    print(f"Wrote {OUT} ({OUT.stat().st_size:,} bytes)")
    print(f"  periods: {payload['meta']['periods']}")
    print(f"  shocks : {payload['meta']['shock_count']}")


if __name__ == "__main__":
    main()
