import pandas as pd
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

OUT = "model_arima/exploration"

df = pd.read_csv("data/clean/phk_master.csv", parse_dates=["date"])
df = df[["province_name_std", "province_code", "year", "month", "date", "phk_flow"]].copy()

last_real_month = df.loc[df["phk_flow"].notna(), "date"].max()
gap_start = last_real_month + pd.DateOffset(months=1)
gap_end = pd.Timestamp("2026-12-01")

provinces = sorted(df["province_name_std"].unique())
n = len(provinces)
print(f"Number of provinces: {n}")

# --- 1. Full small-multiples grid (6 cols x 7 rows = 42 slots for 38 provinces) ---
ncols, nrows = 6, 7
fig, axes = plt.subplots(nrows, ncols, figsize=(18, 16), sharex=True)
axes = axes.flatten()

for i, prov in enumerate(provinces):
    sub = df[df["province_name_std"] == prov].sort_values("date")
    ax = axes[i]
    ax.plot(sub["date"].to_numpy(), sub["phk_flow"].to_numpy(), linewidth=0.9)
    ax.axvspan(gap_start, gap_end, color="grey", alpha=0.25)
    ax.axvline(last_real_month, color="red", linestyle="--", linewidth=0.6)
    ax.set_title(prov, fontsize=8)
    ax.tick_params(axis="both", labelsize=6)
    ax.xaxis.set_major_locator(mdates.YearLocator(2))
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))

for j in range(n, len(axes)):
    axes[j].axis("off")

fig.suptitle("PHK Flow — All 38 Provinces (2022-2026)", fontsize=14)
fig.tight_layout(rect=[0, 0, 1, 0.97])
fig.savefig(f"{OUT}/phk_flow_all_provinces_grid.png", dpi=140)
plt.close(fig)

# --- 2. Overlay chart ---
fig, ax = plt.subplots(figsize=(13, 7))
for prov in provinces:
    sub = df[df["province_name_std"] == prov].sort_values("date")
    ax.plot(sub["date"].to_numpy(), sub["phk_flow"].to_numpy(), linewidth=0.8, alpha=0.35, color="steelblue")

ax.axvspan(gap_start, gap_end, color="grey", alpha=0.25, label="2026 data gap (Aug-Dec)")
ax.axvline(last_real_month, color="red", linestyle="--", linewidth=1, label=f"Last observed month ({last_real_month.strftime('%Y-%m')})")
ax.set_title("PHK Flow — All 38 Provinces, Overlay (2022-2026)")
ax.set_ylabel("Number of layoffs (phk_flow)")
ax.xaxis.set_major_locator(mdates.YearLocator())
ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))
ax.legend(loc="upper left")
fig.tight_layout()
fig.savefig(f"{OUT}/phk_flow_all_provinces_overlay.png", dpi=150)
plt.close(fig)

# --- 3. Data quality check ---
rows = []
for prov in provinces:
    sub = df[df["province_name_std"] == prov].sort_values("date")
    series = sub["phk_flow"]
    non_null = series.dropna()

    n_negative = int((non_null < 0).sum())
    min_val = non_null.min() if len(non_null) else np.nan

    mean_val = non_null.mean() if len(non_null) else np.nan
    std_val = non_null.std() if len(non_null) else np.nan
    if std_val and std_val > 0:
        z = (non_null - mean_val) / std_val
        n_outliers = int((z.abs() > 3).sum())
        max_z = z.abs().max()
    else:
        n_outliers = 0
        max_z = np.nan

    # longest run of exact zeros (within observed/non-null portion, in chronological order)
    zero_flags = (series == 0).astype(int)
    # only consider up to last real month to avoid counting the Aug-Dec 2026 empty gap as zeros
    obs_mask = sub["date"] <= last_real_month
    zf = zero_flags[obs_mask].to_numpy()
    longest_zero_run = 0
    current = 0
    for v in zf:
        if v == 1:
            current += 1
            longest_zero_run = max(longest_zero_run, current)
        else:
            current = 0

    rows.append({
        "province": prov,
        "n_negative": n_negative,
        "min_value": min_val,
        "n_outliers_3sd": n_outliers,
        "max_abs_zscore": round(max_z, 1) if pd.notna(max_z) else np.nan,
        "longest_zero_run_months": longest_zero_run,
        "mean_phk_flow": round(mean_val, 1) if pd.notna(mean_val) else np.nan,
    })

qc = pd.DataFrame(rows).sort_values(
    by=["n_negative", "n_outliers_3sd", "longest_zero_run_months"], ascending=False
)
qc.to_csv(f"{OUT}/phk_flow_data_quality_check.csv", index=False)

flagged = qc[
    (qc["n_negative"] > 0) | (qc["n_outliers_3sd"] > 0) | (qc["longest_zero_run_months"] >= 6)
]

print("\n=== Data quality flags (negative values, 3SD outliers, or >=6 consecutive zero months) ===")
print(flagged.to_string(index=False))

print("\n=== Full QC table saved to phk_flow_data_quality_check.csv ===")
