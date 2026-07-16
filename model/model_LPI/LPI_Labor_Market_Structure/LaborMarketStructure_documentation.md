# LPI — Labor Market Structure (Struktur Tenaga Kerja)

**Layoff Pressure Index (LPI) · Indonesia PHK Early-Warning Dashboard**
Build script: [`01_lpi_labor_market_structure.R`](01_lpi_labor_market_structure.R) · Anchor year: **2023** · Grain: **province-year** · N = **34 provinces**

---

## 1. What this component is

**Labor Market Structure** measures how **formal / modern-sector** each province's labor market is —
the size of the workforce that sits in the *formal, recordable net* and could be recorded as a
layoff (PHK). It is the **exposure pillar** of the LPI: it ranks provinces by *how much is at stake*,
not by whether a shock is happening.

**Actual PHK is the *target* this index is validated against (§5) — never an input.** A high score
(e.g. DKI Jakarta) means a large formal, recordable workforce — the setting in which layoffs register.

## 2. Method

Cross-sectional **PCA** on **5 standardized variables** → **PC1 = the Labor Market Structure score**.

- **Anchor 2023**, province-year grain (master collapsed with `month == 1`). **N = 34.**
- Variables enter in their **natural direction — no inversion.** PC1 is oriented so `formal` loads
  positive ("higher score = more formal / exposed"); the other loadings then fall out naturally
  (agriculture and participation load **negative**; manufacturing and wage load **positive**).
- Statistical adequacy: **KMO = 0.643** (≥ 0.6 acceptable), **Bartlett p = 4.1×10⁻¹⁴**, **PC1 = 58.2%**.

## 3. Specification search — why these 5 variables

Three variables are fixed (agriculture, formal, manufacturing employment shares). Two were chosen from
a **4-way search**: labor-market variable (**TPAK** participation vs **TPT** unemployment) × wage
variable (**UMP** minimum wage vs **Upah** average employee wage):

| Combination | KMO | PC1 % | Validation vs PHK |
|---|---|---|---|
| TPAK + UMP | 0.564 | 49.5% | 0.594 |
| **TPAK + Upah** | **0.643** ✅ | **58.2%** | **0.618** |
| TPT + UMP | 0.412 | 45.2% | 0.568 |
| TPT + Upah | 0.500 | 54.1% | 0.566 |

*(machine-readable: [`outputs/lms_specification_search.csv`](outputs/lms_specification_search.csv))*

**TPAK + Upah wins on every metric** — the only combination clearing **KMO ≥ 0.6**, with the highest
PC1 and the best PHK validation. Two clear lessons from the search:

- **Average wage (Upah) ≫ minimum wage (UMP).** UMP loads ~0 (0.09–0.15) — it is administratively set
  and fairly uniform across provinces, so it carries little cross-province information. **Average
  employee wage genuinely discriminates** developed vs. less-developed provinces (loads 0.44).
- **TPAK > TPT.** Participation gives far better sampling adequacy (KMO 0.56–0.64) than unemployment
  (0.41–0.50); TPT has consistently weak MSA and drags the model down.

## 4. Variables included — the final 5

Natural direction (no inversion); loading sign is relative to the formal-exposure PC1.

| Variable | Definition | Source column | PC1 loading | MSA |
|---|---|---|---:|---:|
| `agri` | Agriculture employment share | `emp_share_agri_pct_y` | **−0.543** | 0.60 |
| `formal` | Formal employment share | `lab_formal_share_pct_y` | +0.527 | 0.64 |
| `wage` | Average employee wage (Upah buruh/karyawan/pegawai) | `wage_avg_employee_idr_y` | +0.443 | 0.87 |
| `manuf` | Manufacturing employment share | `emp_share_manuf_pct_y` | +0.349 | 0.47 |
| `labor` | Labor-force participation rate (TPAK) | `lab_tpak_pct_y` | −0.329 | 0.88 |

*(Weights CSV: [`outputs/lms_loadings.csv`](outputs/lms_loadings.csv).)*

**Reading the signs (formal-exposure gradient):**
- **Positive** — `formal`, `wage`, `manuf` → the **formal / developed** end.
- **Negative** — `agri`, `TPAK` → the **rural / informal** end (high agriculture and high
  participation-in-informal-work mark less-formal provinces).

So PC1 is a clean "how formal / developed is the labor market" axis.

## 5. Validation against actual PHK

Because PHK is the *target*, it is used to **validate** the index (not as an input):

- **Spearman(LMS score, PHK per-worker rate) = 0.618** (N = 34). The exposure index tracks where
  recorded layoffs concentrate — the positive sign is the correct behavior for an *exposure* pillar
  (developed provinces have more recordable formal workers, hence more recorded PHK).

## 6. Robustness

- **(A) Leave-one-out:** refit dropping each province — mean loading change **0.016**, max **0.089**.
  Ranking essentially unchanged (**Spearman = 0.997**); not driven by any single province (incl. DKI).
- **(B) 2024 refit:** KMO **0.612**, PC1 **57.1%**, loading **congruence 0.977**, ranking
  **Spearman 2023 vs 2024 = 0.907** — very stable across years.

## 7. Interpretation of results (2023)

Full ranking: [`outputs/lms_2023_scores.csv`](outputs/lms_2023_scores.csv).

- **Highest:** DKI Jakarta (100), Kepulauan Riau (97), Banten (87), Jawa Barat (70), Kalimantan Timur (69).
- **Lowest:** Papua (0), NTT (11), Sulawesi Barat (16), Bengkulu (23), Lampung (24).
- **Reading:** an exposure/structural gradient — formal, higher-wage, manufacturing-oriented provinces
  score high; agrarian provinces low. In the full LPI this is the **exposure axis**, combined with the
  economic-pressure pillar(s) toward the PHK warning (weights calibrated against actual PHK).

## 8. Caveats

- **Single 2023 cross-section**, N = 34; weights re-fit per year (they are very stable — §6B).
- **KMO 0.643 is "acceptable," not strong** — expected for a 5-variable structural index.
- **Exposure-flavored:** high scores = formal/developed structure; interpret as exposure/context, not
  a standalone layoff forecast.

## 9. Reproducing

```bash
Rscript model/model_LPI/LPI_Labor_Market_Structure/01_lpi_labor_market_structure.R
```

Reads `data/clean/phk_master.csv`; runs the 4-combination search, the final PCA (TPAK + Upah), robustness,
and PHK validation; writes the outputs below.

### Outputs
| File | Contents |
|---|---|
| `outputs/lms_2023_scores.csv` | 34-province index (raw PC1 + 0–100), ranked |
| `outputs/lms_loadings.csv` | Final 5-variable PC1 loadings |
| `outputs/lms_specification_search.csv` | The 4 combinations (KMO, PC1%, validation) |
| `outputs/lms_scree.png` | Scree plot |
