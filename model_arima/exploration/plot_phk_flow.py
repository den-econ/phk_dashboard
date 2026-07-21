import pandas as pd
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

# --- 1. National aggregate (sum across 38 provinces) ---
national = df.groupby("date", as_index=False)["phk_flow"].sum(min_count=1)

fig, ax = plt.subplots(figsize=(12, 5))
ax.plot(national["date"].to_numpy(), national["phk_flow"].to_numpy(), marker="o", markersize=3, linewidth=1.2)
ax.axvspan(gap_start, gap_end, color="grey", alpha=0.2, label="2026 data gap (Aug-Dec, empty rows)")
ax.axvline(last_real_month, color="red", linestyle="--", linewidth=1, label=f"Last observed month ({last_real_month.strftime('%Y-%m')})")
ax.set_title("National PHK Flow (sum across 38 provinces), 2022-2026")
ax.set_xlabel("")
ax.set_ylabel("Number of layoffs (phk_flow)")
ax.xaxis.set_major_locator(mdates.YearLocator())
ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))
ax.legend(loc="upper left")
fig.tight_layout()
fig.savefig(f"{OUT}/phk_flow_national.png", dpi=150)
plt.close(fig)

# --- 2. Top 5-6 provinces by total phk_flow, small multiples ---
totals = df.groupby("province_name_std")["phk_flow"].sum(min_count=1).sort_values(ascending=False)
top_provinces = totals.head(6).index.tolist()

fig, axes = plt.subplots(3, 2, figsize=(13, 10), sharex=True)
axes = axes.flatten()
for i, prov in enumerate(top_provinces):
    sub = df[df["province_name_std"] == prov].sort_values("date")
    ax = axes[i]
    ax.plot(sub["date"].to_numpy(), sub["phk_flow"].to_numpy(), marker="o", markersize=2.5, linewidth=1)
    ax.axvspan(gap_start, gap_end, color="grey", alpha=0.2)
    ax.axvline(last_real_month, color="red", linestyle="--", linewidth=0.8)
    ax.set_title(prov, fontsize=11)
    ax.xaxis.set_major_locator(mdates.YearLocator())
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%Y"))

fig.suptitle("PHK Flow — Top 6 Provinces by Total Layoffs (2022-2026)", fontsize=13)
fig.tight_layout(rect=[0, 0, 1, 0.96])
fig.savefig(f"{OUT}/phk_flow_top6_provinces.png", dpi=150)
plt.close(fig)

print("Last real month:", last_real_month.strftime("%Y-%m"))
print("Top 6 provinces by total phk_flow:")
print(totals.head(6))
print("Saved:", f"{OUT}/phk_flow_national.png", f"{OUT}/phk_flow_top6_provinces.png")
