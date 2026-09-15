"""
Export dashboard outputs (.npy / .npz) to labelled CSV for the Excel audit.

Purpose
-------
The dashboard stores its results as binary numpy arrays, which Excel cannot
read. This script writes them out as CSV with sector names on the rows and
province names on the columns, so they can be pasted straight into the audit
workbook and compared against the hand-built calculation.

This script is READ-ONLY with respect to the pipeline: it never recomputes
anything, it only re-formats what the dashboard already produced. That
separation is the point - the Excel workbook must be an INDEPENDENT
reconstruction, and this file is only the comparison target.

Run:  .venv/bin/python audit/scripts/export_dashboard_outputs.py
Out:  audit/dashboard_export/*.csv
"""
import os, json
import numpy as np
import pandas as pd

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT  = os.path.join(ROOT, "audit", "dashboard_export")
os.makedirs(OUT, exist_ok=True)


# ─── Labels ───────────────────────────────────────────────────────────────────
meta = json.load(open(os.path.join(ROOT, "data", "elasticity", "eta_meta.json")))
prov_ids    = meta["province_order"]      # 34 BPS province codes
prov_labels = meta["province_labels"]     # 34 province names
sect_idx    = meta["sector_order"]        # 1..52
sect_labels = meta["sector_labels"]       # 52 IO52 sector names

# Row/column headers used for every 52x34 export
ROWS = [f"{i:02d}_{n}" for i, n in zip(sect_idx, sect_labels)]
COLS = [f"{i}_{n}"     for i, n in zip(prov_ids, prov_labels)]


def dump(arr, name):
    """Write a 52x34 array as labelled CSV."""
    df = pd.DataFrame(arr, index=ROWS, columns=COLS)
    df.index.name = "sector"
    path = os.path.join(OUT, f"{name}.csv")
    df.to_csv(path)
    return df


# ─── 1. Headline matrices ─────────────────────────────────────────────────────
print("── headline matrices ──")
for name in ["E_matrix", "dL_matrix", "L0_matrix"]:
    arr = np.load(os.path.join(ROOT, "data", "output", f"{name}.npy"))
    dump(arr, name)
    print(f"  {name}.csv                      {arr.shape}  sum={arr.sum():+,.4f}")


# ─── 2. Theme decompositions ──────────────────────────────────────────────────
print("\n── theme decompositions ──")
out_dir = os.path.join(ROOT, "data", "output")
for name in sorted(f[:-4] for f in os.listdir(out_dir) if f.endswith(".npy")):
    if name in ("E_matrix", "dL_matrix", "L0_matrix"):
        continue
    arr = np.load(os.path.join(out_dir, f"{name}.npy"))
    dump(arr, f"decomp_{name}")
print(f"  wrote {len(os.listdir(OUT)) - 3} decomposition CSVs (decomp_*.csv)")


# ─── 3. Province employment shares (the audit's key building block) ───────────
# share[s,p] = province p's fraction of sector s national employment.
# Derived here from L0 so the Excel sheet can be checked against it.
print("\n── derived building blocks ──")
L0 = np.load(os.path.join(ROOT, "data", "output", "L0_matrix.npy"))
with np.errstate(divide="ignore", invalid="ignore"):
    shares = np.where(L0.sum(axis=1, keepdims=True) > 0,
                      L0 / L0.sum(axis=1, keepdims=True), 0.0)
dump(shares, "shares_derived")
rowsum = shares.sum(axis=1)
bad = [(ROWS[i], rowsum[i]) for i in range(len(rowsum)) if abs(rowsum[i] - 1) > 1e-9]
print(f"  shares_derived.csv               rows summing to 1: "
      f"{sum(abs(rowsum-1) < 1e-9)}/52")
if bad:
    print(f"     rows NOT summing to 1: {bad}")


# ─── 4. Elasticity tensor ─────────────────────────────────────────────────────
eta = np.load(os.path.join(ROOT, "data", "elasticity", "eta_matrices.npz"))
for key in eta.files:
    dump(eta[key], f"eta_{key}")
print(f"  eta_*.csv                        {len(eta.files)} matrices")


# ─── 5. Intensity table  (the collapse that makes the Excel audit tractable) ──
# Every placeholder matrix is  eta_j[s,p] = base * intensity_j[s] * share[s,p],
# i.e. it varies across provinces ONLY through share. So it can be reduced to a
# single number per (shock, sector). Recovering it from the tensor:
#     intensity_j[s] = eta_j[s,p] / share[s,p]     (any p with share > 0)
# If that ratio is not constant across p, the collapse does not hold and the
# whole Excel approach must be rethought - so this also VALIDATES the shortcut.
print("\n── intensity table (eta collapse check) ──")
rows, violations = [], []
for key in eta.files:
    M = eta[key]
    r = {"shock": key}
    for s in range(52):
        valid = shares[s] > 0
        if not valid.any():
            r[ROWS[s]] = 0.0
            continue
        ratio = M[s, valid] / shares[s, valid]
        r[ROWS[s]] = float(ratio[0])
        if ratio.max() - ratio.min() > 1e-12:
            violations.append((key, ROWS[s], ratio.min(), ratio.max()))
    rows.append(r)

pd.DataFrame(rows).set_index("shock").to_csv(os.path.join(OUT, "intensity_table.csv"))
print(f"  intensity_table.csv              38 shocks x 52 sectors")
if violations:
    print(f"  !! COLLAPSE FAILS on {len(violations)} (shock,sector) pairs - "
          f"eta is NOT separable, Excel plan needs revision")
    for v in violations[:5]:
        print(f"     {v[0]} / {v[1]}: ratio ranges {v[2]:.6g} .. {v[3]:.6g}")
else:
    print(f"  COLLAPSE HOLDS: eta_j[s,p] = intensity_j[s] * share[s,p] exactly.")
    print(f"  => E[s,p] = share[s,p] * SUM_j( x_j * intensity_j[s] )")


# ─── 6. Applied shock vector ──────────────────────────────────────────────────
agg = json.load(open(os.path.join(ROOT, "data", "output", "aggregation_meta.json")))
sh  = agg["shocks_used"]
pd.DataFrame(
    [{"shock": k, "theme": k.split("_")[0], "x_value_pp": v} for k, v in sh.items()]
).to_csv(os.path.join(OUT, "shocks_applied.csv"), index=False)
print(f"\n── shocks ──\n  shocks_applied.csv               {len(sh)} shocks")


# ─── 7. Provenance record ─────────────────────────────────────────────────────
prov = {
    "exported_from":     "data/output/*.npy + data/elasticity/eta_matrices.npz",
    "data_vintages":     agg["periods"],
    "placeholder_eta":   agg["placeholder"],
    "n_shocks_applied":  len(sh),
    "n_shocks_missing":  len(agg["missing"]),
    "E_min":             agg["E_min"],
    "E_max":             agg["E_max"],
    "dL_total":          agg["dL_total"],
    "matrix_mtime":      __import__("datetime").datetime.fromtimestamp(
                             os.path.getmtime(os.path.join(ROOT, "data", "output",
                                                           "E_matrix.npy"))
                         ).isoformat(timespec="seconds"),
}
json.dump(prov, open(os.path.join(OUT, "_provenance.json"), "w"), indent=2)

print(f"\n{'='*66}")
print(f"Exported {len(os.listdir(OUT))} files to audit/dashboard_export/")
print(f"Vintages: T1={agg['periods']['theme1']}  "
      f"T2={agg['periods']['theme2']['current']}  "
      f"T3={agg['periods']['theme3']}")
print(f"{'='*66}")
