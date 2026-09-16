"""Build the browser-side inputs required to reproduce empdash compute_custom()."""

from __future__ import annotations

import base64
import json
from pathlib import Path

import numpy as np
import pandas as pd


SCRIPT_PATH = Path(__file__).resolve()
REPO_EMPDASH = SCRIPT_PATH.parents[2] / "empdash" if SCRIPT_PATH.parent.parent.name == "dashboard" else None
LOCAL_EMPDASH = Path(r"C:\Users\timot\Documents\empdash")
ROOT = REPO_EMPDASH if REPO_EMPDASH and REPO_EMPDASH.exists() else LOCAL_EMPDASH
OUT = SCRIPT_PATH.parent.parent / "dashboard_empdash_simulator_data.js" if SCRIPT_PATH.parent.parent.name == "dashboard" else SCRIPT_PATH.parents[1] / "dashboard_empdash_simulator_data.js"
TOP5 = {"CHN": "China", "SGP": "Singapore", "JPN": "Japan", "USA": "United States", "PHL": "Philippines"}
T1 = {
    "t1_cpo": "Harga CPO Rotterdam",
    "t1_coal": "Harga batu bara Newcastle",
    "t1_nickel": "Harga nikel LME",
    "t1_copper": "Harga tembaga LME",
    "t1_rubber": "Harga karet TSR20",
    "t1_oilgas": "Harga minyak Brent crude",
    "t1_electronics": "Indeks harga semikonduktor",
}
T3 = {
    "t3_food_bev_tobacco": "Makanan, minuman & tembakau",
    "t3_sandang": "Pakaian & alas kaki",
    "t3_spare_parts": "Suku cadang kendaraan",
    "t3_fuel": "Bahan bakar kendaraan",
    "t3_ict_equipment": "Peralatan ICT & komunikasi",
    "t3_household_equip": "Peralatan rumah tangga",
    "t3_cultural_rec": "Budaya, olahraga & rekreasi",
}


def main() -> None:
    eta_path = ROOT / "data" / "elasticity" / "eta_matrices.npz"
    weights_path = ROOT / "data" / "cache" / "theme2" / "export_weights_52_2023.csv"
    with np.load(eta_path) as eta:
        eta_keys = list(eta.files)
        stacked = np.stack([eta[key] for key in eta_keys]).astype("<f4", copy=False)

    weights = pd.read_csv(weights_path)
    weights = weights[weights["country_iso"].isin(TOP5)]
    t2_weights: dict[str, dict[str, float]] = {}
    for sector_name, group in weights.groupby("sector_name"):
        key = f"t2_{sector_name}"
        if key not in eta_keys:
            continue
        by_country = dict(zip(group["country_iso"], group["w_kc"]))
        t2_weights[key] = {iso: float(by_country.get(iso, 0.0)) for iso in TOP5}

    payload = {
        "shape": list(stacked.shape),
        "etaKeys": eta_keys,
        "etaF32Base64": base64.b64encode(stacked.tobytes(order="C")).decode("ascii"),
        "inputs": {
            "t1": [{"key": key, "label": label} for key, label in T1.items()],
            "t2": [{"key": iso, "label": label} for iso, label in TOP5.items()],
            "t3": [{"key": key, "label": label} for key, label in T3.items()],
        },
        "t2Weights": t2_weights,
        "source": {
            "eta": "empdash/data/elasticity/eta_matrices.npz",
            "weights": "empdash/data/cache/theme2/export_weights_52_2023.csv",
            "formula": "compute_custom: E=sum(input*eta); x_k=sum_c(w_kc*d_g_c); dL=(E/100)*L0",
        },
    }
    OUT.write_text("window.PHK_EMPDASH_SIM_DATA=" + json.dumps(payload, separators=(",", ":")) + ";\n", encoding="utf-8")
    print(f"Wrote {OUT} ({OUT.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
