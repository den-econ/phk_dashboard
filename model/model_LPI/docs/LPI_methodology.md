# LPI Methodology

**Layoff Pressure Index (LPI)** — provincial composite, PHK Early-Warning Dashboard.
Grain: province-year, 2022–2025. Method family: *statistical / PCA–FA weighting*
(OECD-JRC *Handbook on Constructing Composite Indicators*, 2008, §6.1; Nicoletti
et al., 2000). **Recorded PHK validates the indices; it is never an input.**

## Overview

The LPI is a **two-stage (nested) composite**:

- **Stage 1 — three pillars.** Two are first-layer PCA indices built from
  standardised province-year variables (each PC1 = the pillar score); the third
  is the LEI pressure index aggregated to annual.
  - **Indeks Kerentanan Pasar Kerja** — formal share, manufacturing labour share,
    full-time share, underemployment (−), average wage. Oriented so *formal labour
    share* loads positive.
  - **Indeks Kerentanan Struktural Ekonomi** — Government/PDRB, Export/PDRB,
    Import/PDRB, Manufacturing %PDRB, Agriculture %PDRB (compositional reference
    categories consumption & services, and the inert mining axis, removed).
    Oriented so *manufacturing %PDRB* loads positive.
  - **Indeks Tekanan Makroekonomi** — annual mean of the monthly LEI
    (`Indeks_LEI_Labour`), a timing/pressure signal.

- **Stage 2 — data-driven weights.** A second PCA over the three standardised
  pillar scores derives the weights (below), aggregating them into the LPI.

## Stage-2 weighting (OECD §6.1), per year

1. **Standardise** the three pillar scores to mean 0, SD 1 within the year.
2. **Correlation matrix** of the three standardised pillars.
3. **PCA** → eigenvalues (sum to 3).
4. **Retain m = 2 factors** — eigenvalue > 1 *or "close to 1"* (the OECD example
   retains a ~0.9 factor), each > 10% and together > 60%. Empirically this is a
   *Kerentanan* dimension (Pasar Kerja + Struktural) and a *Tekanan* dimension
   (Makroekonomi); the residual third dimension is dropped.
5. **Varimax rotation** of the two factors → clean structure (each pillar loads
   mainly on one factor).
6. **Weights:** for each pillar, weight = (its squared-loading share *within* its
   assigned factor) × (that factor's share of retained variance); normalise to
   100%.

**Key judgement:** retaining the second factor (eigenvalue ~0.9–1.0). It is what
gives Tekanan Makroekonomi a real, stable weight — the pillar loads ~0.98 on
factor 2 and ~0.08 on factor 1, so dropping factor 2 would collapse the index to
the vulnerability story and near-ignore macro pressure.

## Composite score

Per province: **LPI = weighted sum of its three standardised pillar scores**
(that year's weights), then **min-max rescaled to 0–100 within the year**.
Higher = more layoff pressure. Because pillars are standardised and re-fit each
year, the 0–100 LPI is a **within-year ranking**, not a cross-year level (the raw
weighted sum is also exported in `lpi_scores_long.csv` as `lpi_raw`).

## Resulting weights (Pasar Kerja / Struktural / Tekanan)

| Year | N | Pasar Kerja | Struktural | Tekanan |
|---|---|---|---|---|
| 2022 | 34 | 30.6% | 31.8% | 37.7% |
| 2023 | 33 | 33.0% | 32.9% | 34.1% |
| 2024 | 36 | 30.2% | 30.9% | 38.9% |
| 2025 | 35 | 26.3% | 33.2% | 40.6% |
| **mean** | | **30.0%** | **32.2%** | **37.8%** |

## Provincial tiers

Provinces are split into **4 equal-count tiers** (quartiles by LPI rank):
Risiko Sangat Tinggi → Risiko Tinggi → Risiko Sedang → Risiko Rendah.

## Validation (never an input)

Each pillar is validated by Spearman rank correlation against recorded PHK
(per 100k formal workers, and total) — see `outputs/pillar_metrics.csv`. The two
vulnerability pillars validate ~0.40–0.66; Tekanan Makroekonomi adds an
independent early-warning signal.

## Reproduce

`cd model/model_LPI && bash code/run_all.sh`. See the provenance note in
`README.md` regarding `outputs/models.rds`.
