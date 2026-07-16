# LPI — Labor Market Structure (Struktur Tenaga Kerja)

**Layoff Pressure Index (LPI) · Indonesia PHK Early-Warning Dashboard**
Build script: [`01_lpi_labor_market_structure.R`](01_lpi_labor_market_structure.R) · Anchor year: **2023** · Grain: **province-year** · N = **33 provinces**

> This indicator **merges** the earlier Component 1 ("Labor Exposure") and Component 2 ("Labor Market
> Signals") into one PCA index. The final **9-variable** set was selected from an extensive
> specification search (§3): a 7-variable core plus `unpaid family workers` and the `Kaitz index`, which
> together raise both statistical adequacy (KMO) and the validation against actual PHK.

---

## 1. What this component is

**Labor Market Structure** measures how *formal, modern-sector, slack, and informal* each province's
labor market is — combining structural composition (formality, sector mix), current labor-market
conditions (participation, unemployment, jobseekers), and informality/wage structure (unpaid family
work, Kaitz index). **Higher score = a labor-market structure more exposed and vulnerable to recorded
layoffs.**

It is the **structural pillar** of the LPI. **Actual PHK is the *target* this index is validated
against (§5) — never an input.** A high score (e.g. DKI Jakarta) means a large, formal, recordable
workforce operating under measurable labor slack — the setting in which layoffs would register — not a
forecast that layoffs are imminent.

## 2. Method

Cross-sectional **PCA** on 9 standardized, pressure-oriented variables → **PC1 = the Labor Market
Structure score**.

- **Anchor 2023**; province-year grain (master collapsed with `month == 1`). **N = 33** (the 4 new
  Papua DOB provinces and Kepulauan Riau drop on missing inputs).
- Inputs are **shares / rates** (intensity), so province *size* does not dominate.
- All variables **standardized** (z-score) and oriented so higher = more pressure and loads positive
  (reversals documented — the sign of an individual variable does not change the PCA scores).
- Statistical adequacy: **KMO = 0.685** (≥ 0.6 acceptable), **Bartlett p = 2.5×10⁻²⁷**, **PC1 = 50.2%**,
  **3 factors** (eigenvalue > 1). Scores reported as raw PC1 and a 0–100 rescale.

## 3. Specification search — why these 9

The variable set was chosen empirically, comparing candidate specifications on **PCA adequacy (KMO),
single-factor strength (PC1%), dimensionality, and validation against actual PHK**:

| Spec | # vars | KMO | PC1 % | Factors > 1 | Validation vs PHK |
|---|---|---|---|---|---|
| Core (7) | 7 | 0.660 | 50.7% | 2 | 0.567 |
| + unpaid family | 8 | 0.655 | 53.6% | 3 | 0.583 |
| + Kaitz | 8 | 0.680 | 47.8% | 3 | 0.563 |
| **FINAL: + unpaid + Kaitz** | **9** | **0.685** ✅ | 50.2% | 3 | **0.592** |
| + vacancies/placements | 11 | 0.573 | 42.8% | 4 | 0.607 |

*(machine-readable: [`outputs/lms_specification_search.csv`](outputs/lms_specification_search.csv))*

**Why the 9-variable set:** it has the **highest KMO (0.685)** and a strong PC1 (50.2%). Adding `unpaid
family` and `Kaitz` improves adequacy, PHK validation (0.567 → 0.592), *and* year-to-year stability (§6).
Going further (vacancies/placements) collapses KMO to 0.57 and adds a 4th factor. The 11-variable spec
validates marginally higher (0.607) but that gain is within noise (SE ≈ 0.18 at N=33) and costs adequacy.

**What was tested and excluded** (each lowered KMO and/or PHK validation):
- **Labor-registry demand** (vacancies, placements) — Kemnaker administrative-data noise; drags KMO.
- **Statistik-industri** (workers/firm, output & VA per worker, PMDN, industrial growth) — measures
  *manufacturing-sector performance*, a different construct; fragments the index into 6–7 factors.
- **Momentum / change** variables — a level and its own change are near-uncorrelated (~0.06); separate weak factors.
- **BPJS layoff/claims (JKP, JHT) and PHK flow/stock** — these *are* the target (corr 0.92–0.94 with PHK);
  including them is circular. → validation only.

## 4. Variables included — the final 9

All oriented so **higher = more pressure** (and, by convention, loading positive).

| Variable | Definition | Source column / formula | Orientation | PC1 loading | MSA |
|---|---|---|:--:|---:|---:|
| `agri` | Agriculture employment share, **inverted** | `emp_share_agri_pct_y` | − | 0.433 | 0.82 |
| `unpaid` | Unpaid family workers (share of working pop), **inverted** | `100 × lab_unpaid_family_y ÷ lab_working_pop_y` | − | 0.408 | 0.70 |
| `formal` | Formal employment share | `lab_formal_share_pct_y` | + | 0.405 | 0.72 |
| `bpjs_pu` | BPJS-TK wage-earner (PU) coverage | `100 × bpjstk_active_pu_y ÷ lab_working_pop_y` | + | 0.405 | 0.82 |
| `tpak` | Labor-force participation rate, **inverted** | `lab_tpak_pct_y` | − | 0.297 | 0.54 |
| `manuf` | Manufacturing employment share | `emp_share_manuf_pct_y` | + | 0.260 | 0.53 |
| `kaitz` | Kaitz index (min/median wage), **inverted** | `wage_kaitz_index_y` | − | 0.249 | 0.82 |
| `jobseek` | Registered jobseekers | `100 × lab_job_seekers_y ÷ lab_working_pop_y` | + | 0.243 | 0.59 |
| `tpt` | Unemployment rate (TPT) | `lab_tpt_pct_y` | + | 0.205 | 0.46 |

*(PC1 = weight on the index; MSA = per-variable sampling adequacy. Weights CSV:
[`outputs/lms_loadings.csv`](outputs/lms_loadings.csv).)*

The structural / informality variables (`agri`, `unpaid`, `formal`, `bpjs_pu`, `kaitz`) carry the top
loadings; the conditions variables (`tpak`, `manuf`, `jobseek`, `tpt`) attach as a secondary overlay.
Note `unpaid` and `kaitz` enter **inverted** — fewer unpaid family workers and a lower Kaitz ratio mark
the more formal / developed end of the gradient. (Reminder: inverting a single variable only flips its
loading sign; it does not change the scores, ranking, KMO, or validation.)

## 5. Validation against actual PHK

Because PHK is the *target*, it is used to **validate** the index (not as an input):

- **Spearman(LMS score, actual PHK 2023) = 0.592** (N = 33). The structural index — which contains **no
  PHK data** — tracks real provincial layoffs at ~0.59. This is the core proof the approach works.
- Across specs, validation ranges 0.57–0.61 with differences **within noise** (SE ≈ 0.18) — the
  structural core does the real work; the 9-variable set is the best all-round.

## 6. Robustness

- **(A) Leave-one-out:** refit dropping each province — mean loading change **0.017**, max **0.133**
  (dropping DKI Jakarta). The ranking is essentially unchanged (**Spearman = 0.997**), so the index is
  **not driven by any single province**.
- **(B) 2024 refit:** KMO **0.726**, PC1 **46.9%**, **ranking Spearman 2023 vs 2024 = 0.856**, loading
  **congruence = 0.599** — all *improved* versus the 7-variable core (0.61 / 0.51 / 0.83). Adding `unpaid`
  + `Kaitz` made the index more year-stable. Still, re-standardize/refit per year rather than freezing the
  exact weights.

## 7. Interpretation of results (2023)

Full ranking: [`outputs/lms_2023_scores.csv`](outputs/lms_2023_scores.csv).

- **Highest structure score:** DKI Jakarta (100), Banten (98), Jawa Barat (86), Kalimantan Timur (80),
  Sulawesi Utara (75).
- **Lowest:** Papua (0), NTT (21), Sulawesi Barat (32), NTB (36), Bengkulu (37).
- **Reading:** the index is anchored on the **formal / urban / developed structural gradient** (which is
  why DKI and Banten top it), with labor-conditions riding along. It is best read as *"how exposed and
  slack this province's labor-market structure is"* — a **structural/exposure** measure, **not** a
  standalone layoff warning. In the full LPI it is the **conditioning axis**, combined with the
  economic-pressure and external pillars via `Risk = Exposure × Pressure` (kept separate, not averaged).

## 8. Caveats to carry forward

- **Single 2023 cross-section**, N = 33; weights re-fit per year (not frozen — see §6B).
- **KMO 0.685 is "acceptable," not strong**, and the index has **3 factors** — a merged index spanning
  structure + conditions + informality is inherently multi-dimensional; PC1 (50%) is the dominant axis.
- **Exposure-flavored:** high scores reflect formal/urban structure; interpret as exposure/context, not a
  direct forecast.
- 4 new Papua provinces + Kepulauan Riau are out of the 2023 sample (missing inputs).
- `tpt` (MSA 0.46) and `manuf` (0.53) are the weakest-fitting retained variables — monitor.

## 9. Reproducing

```bash
Rscript model/model_LPI/LPI_Labor_Market_Structure/01_lpi_labor_market_structure.R
```

Reads `data/clean/phk_master.csv`; runs the specification search, the final 9-variable index (with
KMO/Bartlett/scree diagnostics), robustness, and PHK validation; writes the outputs below. No other files
are touched.

### Outputs
| File | Contents |
|---|---|
| `outputs/lms_2023_scores.csv` | 33-province Labor Market Structure index (raw PC1 + 0–100), ranked |
| `outputs/lms_loadings.csv` | Final 9-variable PC1 weights + orientation |
| `outputs/lms_specification_search.csv` | Candidate-spec comparison (KMO, PC1%, factors, PHK validation) |
| `outputs/lms_scree.png` | Scree plot |
