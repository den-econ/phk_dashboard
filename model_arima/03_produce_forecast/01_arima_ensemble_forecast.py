"""
ARIMA-Ensemble PHK forecast (production)
=========================================

Produces a 6-month-ahead phk_flow forecast for all 34 reporting provinces,
using a per-province tiered ensemble of three simple forecasting methods
(Simple Mean, Simple Exponential Smoothing, plain ARIMA).

This script implements the approach validated during the ARIMA exploration
work in `model_arima/exploration/`. Summary of what was tested and why this
specific design was chosen:

  - Plain ARIMA alone does not reliably beat a naive random-walk or a simple
    historical mean across the 34-province panel (see
    exploration/simple_methods_comparison_CLIPPED.csv and
    exploration/seasonal_forward_test_full.csv).
  - Seasonal terms (SARIMA) and an exogenous macro/financial deterioration
    score were both tested and did not improve out-of-sample accuracy on
    average (see exploration/run_seasonal_forward_test.py results) - they are
    intentionally NOT included here.
  - A tiered ensemble - weighting Mean/SES/ARIMA differently depending on how
    volatile a province's series is - gave the best average out-of-sample
    MASE of every method tested, and was also more robust than picking a
    single "best" method per province from a validation year (see
    exploration/run_two_stage_validation.py - per-province selection
    overfit to its validation year in 8/34 provinces; the uniform tiered
    ensemble did not have this failure mode).

Data-quality handling
----------------------
  - 5 provinces have a single erroneous negative `phk_flow` value in the raw
    data (confirmed: Bangka Belitung, DKI Jakarta, Jawa Tengah, Papua Barat,
    Sumatera Selatan). These are clipped to zero before any calculation.
  - `lab_working_pop_y` (the employed-population denominator used to build
    the `phk_rate` per-1,000-workers metric) is not published for any month
    in 2026. Rather than silently mixing rate-scale and count-scale values
    within one series (which would corrupt the ARIMA fit), each province's
    usable history is TRUNCATED to its last month with a valid
    `lab_working_pop_y`, and modeled as `phk_rate` from there. This means
    `last_observed_month` (and therefore the 6-month forecast window) can
    be earlier than the panel's absolute latest month for provinces whose
    denominator lagged behind their `phk_flow` reporting - this is expected
    and is reported explicitly per province.
      A province only falls back to modeling raw `phk_flow` (clipped)
    directly if it has NO valid `lab_working_pop_y` anywhere in its history
    (checked explicitly below; as of this run, no province actually hits
    this case - every province has at least some historical months with a
    valid denominator).
    This is recorded per province in `used_raw_count_fallback`.

  - Forecasts are clipped at zero at the final output step
    (`implied_phk_count_forecast = max(0, forecast)`). This is a
    display-layer safeguard only - it does not change the underlying
    model or its intermediate calculations. Plain (linear) ARIMA has no
    built-in floor at zero and can produce a negative point forecast for
    a strictly non-negative quantity like a layoff count; clipping at
    the very end is the standard, minimal fix for this known limitation.

Usage
-----
    python 01_arima_ensemble_forecast.py

Output
------
    model_arima/03_produce_forecast/output/phk_forecast_production.csv
"""

import os
import warnings

import numpy as np
import pandas as pd
from statsmodels.tsa.holtwinters import SimpleExpSmoothing
from statsmodels.tsa.stattools import adfuller
from statsmodels.tsa.statespace.sarimax import SARIMAX

warnings.filterwarnings("ignore")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
INPUT_PATH = os.path.join(REPO_ROOT, "data", "clean", "phk_master.csv")
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "output")
OUTPUT_PATH = os.path.join(OUTPUT_DIR, "phk_forecast_production.csv")

FORECAST_HORIZON_MONTHS = 6
MIN_HISTORY_MONTHS = 15          # minimum usable months to attempt any fit
ARIMA_ORDER_SEARCH_RANGE = range(0, 3)  # p, q in [0, 1, 2]; d chosen via ADF test

# Ensemble weights per volatility tier: (Mean, SES, ARIMA)
TIER_WEIGHTS = {
    "Quiet": {"Mean": 0.70, "SES": 0.15, "ARIMA": 0.15},
    "Moderate": {"Mean": 0.50, "SES": 0.50, "ARIMA": 0.00},
    "High-vol": {"Mean": 0.15, "SES": 0.15, "ARIMA": 0.70},
}
TIER_LABELS = {"Quiet": "70/15/15", "Moderate": "50/50/0", "High-vol": "15/15/70"}


# ---------------------------------------------------------------------------
# Step 1: load and clean data
# ---------------------------------------------------------------------------
def load_and_clean_data(path):
    """Load phk_master.csv, clip negative phk_flow, and build a per-province
    modeling series on a single consistent scale (phk_rate or raw phk_flow).
    """
    raw = pd.read_csv(path, parse_dates=["date"])
    df = raw[["province_name_std", "date", "phk_flow", "lab_working_pop_y"]].copy()
    df = df.rename(columns={"province_name_std": "province"})
    df = df.sort_values(["province", "date"]).reset_index(drop=True)

    df["phk_flow_clipped"] = df["phk_flow"].clip(lower=0)
    df["phk_rate"] = np.where(
        df["lab_working_pop_y"].notna(),
        (df["phk_flow_clipped"] / df["lab_working_pop_y"]) * 1000,
        np.nan,
    )

    # Drop provinces with no data at all (e.g. new Papua splits with no
    # PHK reporting history yet).
    has_data = df.groupby("province")["phk_flow"].transform(lambda s: s.notna().any())
    df = df[has_data].reset_index(drop=True)

    return df


def build_modeling_series(df, province):
    """Decide the modeling scale for one province and return:
        series          - the chosen series, indexed by date
        used_raw_fallback - bool, True only if the province has NO valid
                           lab_working_pop_y anywhere in its history
        last_lab_working_pop - most recent known lab_working_pop_y value,
                           used to convert phk_rate forecasts back to
                           implied counts

    Provinces WITH at least one valid denominator: history is truncated to
    the last month with a valid `lab_working_pop_y`, and modeled as
    `phk_rate` from there (Option B - see module docstring). This means
    `last_observed_month` may be earlier than the province's last reported
    `phk_flow` month.
    """
    sub = df[df["province"] == province].sort_values("date").set_index("date")

    has_any_denominator = sub["lab_working_pop_y"].notna().any()

    if not has_any_denominator:
        # No valid denominator ever - only option is to model raw counts.
        series = sub["phk_flow_clipped"].dropna()
        used_raw_fallback = True
        last_known_lab_working_pop = np.nan
        return series, used_raw_fallback, last_known_lab_working_pop

    last_denominator_month = sub["lab_working_pop_y"].dropna().index.max()
    truncated = sub.loc[:last_denominator_month]
    series = truncated["phk_rate"].dropna()
    used_raw_fallback = False
    last_known_lab_working_pop = sub.loc[last_denominator_month, "lab_working_pop_y"]

    return series, used_raw_fallback, last_known_lab_working_pop


# ---------------------------------------------------------------------------
# Step 2: volatility tier (tercile cutoffs recomputed fresh on this dataset)
# ---------------------------------------------------------------------------
def compute_naive_mae(series):
    """Mean absolute error of a naive one-step-ahead (random-walk) forecast."""
    return series.diff().abs().dropna().mean()


def assign_volatility_tiers(naive_mae_by_province):
    """Tercile cutoffs on naive_mae, computed fresh on the current dataset
    (not hardcoded from earlier validation runs, since more months are
    available now than during validation).
    """
    values = pd.Series(naive_mae_by_province)
    low_cutoff, high_cutoff = values.quantile([1 / 3, 2 / 3])

    def tier_of(x):
        if x <= low_cutoff:
            return "Quiet"
        elif x <= high_cutoff:
            return "Moderate"
        return "High-vol"

    tiers = {p: tier_of(v) for p, v in naive_mae_by_province.items()}
    return tiers, low_cutoff, high_cutoff


# ---------------------------------------------------------------------------
# Step 3: fit the three component methods on full history
# ---------------------------------------------------------------------------
def fit_simple_mean(series, horizon, forecast_index):
    return pd.Series([series.mean()] * horizon, index=forecast_index)


def fit_ses(series, horizon, forecast_index):
    model = SimpleExpSmoothing(series, initialization_method="estimated").fit(optimized=True)
    forecast = model.forecast(horizon)
    forecast.index = forecast_index
    return forecast


def fit_arima(series, horizon, forecast_index):
    """Plain (non-seasonal, no exogenous) ARIMA. Differencing order chosen via
    an ADF stationarity test; (p, q) chosen by AIC grid search - this mirrors
    the validated approach from the exploration phase (pmdarima's auto_arima
    is not installed in this environment; this grid search is the documented
    substitute).
    """
    is_stationary = adfuller(series)[1] < 0.05
    d = 0 if is_stationary else 1

    best_aic, best_fit = np.inf, None
    for p in ARIMA_ORDER_SEARCH_RANGE:
        for q in ARIMA_ORDER_SEARCH_RANGE:
            try:
                model = SARIMAX(
                    series, order=(p, d, q),
                    enforce_stationarity=False, enforce_invertibility=False,
                )
                fit = model.fit(disp=False)
                if fit.aic < best_aic:
                    best_aic, best_fit = fit.aic, fit
            except Exception:
                continue

    if best_fit is None:
        # No ARIMA spec converged - fall back to the historical mean rather
        # than letting the whole province fail.
        return fit_simple_mean(series, horizon, forecast_index)

    forecast = best_fit.get_forecast(steps=horizon).predicted_mean
    forecast.index = forecast_index
    return forecast


# ---------------------------------------------------------------------------
# Step 4: tiered ensemble
# ---------------------------------------------------------------------------
def combine_ensemble(mean_fc, ses_fc, arima_fc, tier):
    w = TIER_WEIGHTS[tier]
    return w["Mean"] * mean_fc + w["SES"] * ses_fc + w["ARIMA"] * arima_fc


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------
def main():
    df = load_and_clean_data(INPUT_PATH)
    provinces = sorted(df["province"].unique())

    # Pass 1: build each province's modeling series and naive_mae, needed
    # up front to assign volatility tiers using the full 34-province spread.
    province_data = {}
    naive_mae_by_province = {}

    for province in provinces:
        series, used_raw_fallback, last_lab_working_pop = build_modeling_series(df, province)
        if len(series) < MIN_HISTORY_MONTHS:
            continue
        province_data[province] = {
            "series": series,
            "used_raw_fallback": used_raw_fallback,
            "last_lab_working_pop": last_lab_working_pop,
        }
        naive_mae_by_province[province] = compute_naive_mae(series)

    fallback_provinces = [p for p, d in province_data.items() if d["used_raw_fallback"]]
    print(f"Provinces with NO valid lab_working_pop_y anywhere in their history "
          f"(raw-count fallback required): {fallback_provinces if fallback_provinces else 'none'}")

    tiers, low_cutoff, high_cutoff = assign_volatility_tiers(naive_mae_by_province)
    print(f"Volatility tier cutoffs (naive_mae terciles): "
          f"Quiet <= {low_cutoff:.5f} <= Moderate <= {high_cutoff:.5f} <= High-vol")

    # Pass 2: fit, forecast, and assemble the output table.
    output_rows = []
    for province, data in province_data.items():
        series = data["series"]
        tier = tiers[province]
        horizon = FORECAST_HORIZON_MONTHS

        last_observed_month = series.index.max()
        forecast_index = pd.date_range(
            last_observed_month + pd.DateOffset(months=1), periods=horizon, freq="MS"
        )

        mean_fc = fit_simple_mean(series, horizon, forecast_index)
        ses_fc = fit_ses(series, horizon, forecast_index)
        arima_fc = fit_arima(series, horizon, forecast_index)
        ensemble_fc = combine_ensemble(mean_fc, ses_fc, arima_fc, tier)

        for month in forecast_index:
            modeled_value = ensemble_fc.loc[month]

            if data["used_raw_fallback"]:
                phk_rate_forecast = np.nan  # not modeled on the rate scale
                implied_count_forecast = modeled_value
            else:
                phk_rate_forecast = modeled_value
                implied_count_forecast = modeled_value * data["last_lab_working_pop"] / 1000

            # Display-layer safeguard only (see module docstring): plain
            # ARIMA has no floor at zero and can forecast a negative count
            # for a strictly non-negative quantity. Clip here, not upstream.
            implied_count_forecast = max(0.0, implied_count_forecast)

            output_rows.append({
                "province": province,
                "forecast_month": month.strftime("%Y-%m"),
                "volatility_tier": tier,
                "phk_rate_forecast": round(phk_rate_forecast, 5) if pd.notna(phk_rate_forecast) else np.nan,
                "implied_phk_count_forecast": round(implied_count_forecast, 1),
                "used_raw_count_fallback": data["used_raw_fallback"],
                "method_weights_used": TIER_LABELS[tier],
                "last_observed_month": last_observed_month.strftime("%Y-%m"),
            })

        print(f"{province}: tier={tier}, last_observed={last_observed_month.strftime('%Y-%m')}, "
              f"raw_count_fallback={data['used_raw_fallback']}, "
              f"forecast {forecast_index[0].strftime('%Y-%m')} to {forecast_index[-1].strftime('%Y-%m')}")

    output_df = pd.DataFrame(output_rows)

    # Flag provinces whose ensemble forecast swings by a large amount
    # month-to-month within the 6-month window - a sign of an unstable fit
    # rather than a genuine expected pattern (e.g. Kalimantan Timur was
    # found to swing to a negative raw forecast pre-clipping during review).
    output_df["pct_change"] = (
        output_df.sort_values(["province", "forecast_month"])
        .groupby("province")["implied_phk_count_forecast"]
        .pct_change()
    )
    unstable_provinces = output_df.loc[output_df["pct_change"].abs() > 0.5, "province"].unique()
    output_df["flagged_unstable"] = output_df["province"].isin(unstable_provinces)
    output_df = output_df.drop(columns=["pct_change"])

    if len(unstable_provinces):
        print(f"\nFLAGGED as unstable (>50% month-to-month swing in forecast): "
              f"{list(unstable_provinces)}")

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_df.to_csv(OUTPUT_PATH, index=False)
    print(f"\nSaved {len(output_df)} rows to {OUTPUT_PATH}")

    return output_df


if __name__ == "__main__":
    main()
