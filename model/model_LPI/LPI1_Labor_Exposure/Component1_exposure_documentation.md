# LPI Component 1 — Labor Exposure to Recorded PHK

**Layoff Pressure Index (LPI) · Indonesia PHK Early-Warning Dashboard**
Build script: [`01_lpi_component1_exposure.R`](01_lpi_component1_exposure.R) · Anchor year: **2023** · Grain: **province-year** · N = **34 provinces**

> **Transparency note.** This component was built in two stages that are both kept in the code:
> **Stage A** fits a PCA on the *full original 10-variable candidate set*; **Stage B** narrows to a
> *final 5-variable set* via two documented filters. Nothing is dropped silently — every candidate,
> its loadings, and the reason it was kept or removed are recorded here and in
> [`outputs/candidate_full_pca_loadings.csv`](outputs/candidate_full_pca_loadings.csv).

---

## 1. What this component is (and is not)

Component 1 measures **labor exposure to *recorded* PHK** — how large and formal each
province's workforce is, i.e. the pool of workers that *can be formally recorded* as laid
off. It is an **exposure / context axis, not a layoff-warning score.**

- A high value (e.g. **DKI Jakarta = 100**) means a large formal, recordable workforce — the
  **denominator of potential recorded PHK** — **not** that layoffs are imminent.
- Exposure is deliberately kept **separate** from the pressure/warning components (2–4) and is
  **never summed** into a warning score. Its intended uses: (a) a standalone axis, (b) one axis
  of a 2-D Exposure × Pressure map, (c) optionally a multiplier if a `Risk = Exposure × Pressure`
  view is built later.

This separation resolves the "DKI problem": a province with many formal workers should rank
high on **exposure**, without being auto-classified as high **warning**.

## 2. Method

Single-year cross-sectional **PCA**; **PC1 = exposure score**.

- **Anchor 2023** — statistik-industri and full Sakernas structural variables present for 34
  provinces. (The 4 new Papua DOB provinces — Papua Selatan, Tengah, Pegunungan, Barat Daya —
  have no 2023 structural data and drop out.)
- Inputs are **shares / ratios only** (intensity), so province *size* does not dominate.
- Variables enter **standardized** (`center + scale`). PCA does not require pre-signed inputs;
  the agriculture sign-flip and PC1 orientation are purely for interpretability.
- **Stage A** (full 10 vars): PC1 = 53.5%. **Stage B** (final 5 vars): **PC1 = 74.4%** (PC2 17.0%).
- Score is reported as raw **PC1** and a **0–100** min–max rescale.

## 3. Variable selection — full candidate set and the evidence

### 3.1 Stage A: PCA on the full original 10-variable candidate set (N = 34)

Loadings on the first two components, and the keep/drop decision for each:

| Variable | PC1 loading | PC2 loading | Decision |
|---|---:|---:|---|
| agri_share (inv) | **0.418** | −0.05 | **KEEP** |
| employee_share | 0.399 | 0.16 | DROP — duplicate of `formal_share` (r = 1.00) |
| formal_share | **0.392** | 0.20 | **KEEP** |
| bpjs_pu_share | **0.385** | 0.06 | **KEEP** |
| services_share | **0.384** | 0.09 | **KEEP** |
| labor_intensity | 0.376 | −0.19 | DROP — near-duplicate of `manuf_share` (r = 0.89) |
| manuf_share | **0.263** | −0.40 | **KEEP** |
| workers_perfirm | −0.061 | −0.43 | DROP — off-axis (loads on PC2) |
| contract_share | 0.058 | −0.53 | DROP — off-axis (loads on PC2) |
| pmdn_share | 0.004 | 0.51 | DROP — off-axis (loads on PC2) |

*(machine-readable: [`outputs/candidate_full_pca_loadings.csv`](outputs/candidate_full_pca_loadings.csv))*

### 3.2 The two filters

**Filter 1 — drop what is not exposure (3 variables).** There is a sharp gap in the PC1 column:
seven variables load 0.26–0.42, then it collapses to ≈ 0 for `workers_perfirm` (−0.06),
`contract_share` (0.06), and `pmdn_share` (0.00). These three carry **no exposure signal** — they
instead load heavily on **PC2** (−0.43, −0.53, +0.51), a *separate* contract-vs-ownership /
firm-structure contrast (only 18% of variance), not exposure. Keeping them would inject an
off-topic axis into the score.

**Filter 2 — drop duplicates among the survivors (2 variables).** Of the 7 that *do* load on the
exposure axis, two are statistically the same as a variable already kept:
- `employee_share` ↔ `formal_share`: **r = 1.00** (literal duplicate)
- `labor_intensity` ↔ `manuf_share`: **r = 0.89** (near-duplicate; labor-intensity is dominated by manufacturing)

Including both members of a duplicated pair merely **double-weights that concept** without adding
information.

**Survivors after both filters = the final 5:** `formal_share`, `bpjs_pu_share`, `services_share`,
`manuf_share`, `agri_share(−)`.

### 3.3 Why this is the right call, not just tidier

| | Full 10-var (Stage A) | Final 5-var (Stage B) |
|---|---|---|
| PC1 variance explained | 53.5% | **74.4%** |
| Province ranking vs. full set | — | **Spearman 0.996** (essentially identical order) |
| Loadings | uneven, several ≈ 0 | clean, near-equal |

The dropped variables had ~0 weight anyway, so the ranking barely moves (0.996) — but the index
becomes a single interpretable axis at 74% instead of a muddy 53% mixing in an off-topic PC2.

## 4. Variables INCLUDED — the final 5

All oriented so that **higher = more exposure**.

| Variable | Source column / formula | Orientation | 2023 PC1 loading | What it captures |
|---|---|:--:|---:|---|
| `agri_share` | `− emp_share_agri_pct_y` *(sign-flipped)* | **−** | 0.501 | Agriculture share; large agri = informal-buffer workforce = **low** exposure |
| `formal_share` | `lab_formal_share_pct_y` | **+** | 0.469 | % of workers in formal employment |
| `bpjs_pu_share` | `100 × bpjstk_active_pu_y ÷ lab_working_pop_y` *(derived)* | **+** | 0.469 | BPJS-TK wage-earner (PU) coverage — most direct proxy for the formal social-security net that can file recorded PHK/JKP claims |
| `services_share` | Σ of 11 service-sector `emp_share_*_pct_y` *(derived, `na.rm`)* | **+** | 0.469 | Services employment share |
| `manuf_share` | `emp_share_manuf_pct_y` | **+** | 0.299 | Manufacturing employment share (high-recordability, layoff-prone) |

*Weights CSV: [`outputs/exposure_component1_loadings.csv`](outputs/exposure_component1_loadings.csv).
Full ranking: [`outputs/exposure_component1_2023_scores.csv`](outputs/exposure_component1_2023_scores.csv)
(top: DKI Jakarta, Kepulauan Riau, Banten, Kalimantan Timur; bottom: Papua, NTT, Sulawesi Barat, Bengkulu).*

**Derived-variable definitions**

- **`bpjs_pu_share`** = `100 × bpjstk_active_pu_y / lab_working_pop_y`.
- **`services_share`** = row-sum, `na.rm = TRUE`, of: `emp_share_trade_pct_y`,
  `emp_share_transport_pct_y`, `emp_share_accom_food_pct_y`, `emp_share_info_comm_pct_y`,
  `emp_share_finance_pct_y`, `emp_share_real_estate_pct_y`, `emp_share_business_svc_pct_y`,
  `emp_share_public_admin_pct_y`, `emp_share_education_pct_y`, `emp_share_health_pct_y`,
  `emp_share_other_svc_pct_y`. `na.rm = TRUE` treats a blank micro-sector (e.g. real-estate
  employment in a small province) as 0 rather than nulling the whole sum — keeping Gorontalo,
  Maluku Utara, and Sulawesi Barat in the sample (34 provinces instead of 31).
- **`agri_share`** = `− emp_share_agri_pct_y` (sign flip so the buffer reads as low exposure).
- *(Stage-A only)* **`employee_share`** = `100 × lab_employee_count_y / lab_working_pop_y`;
  **`labor_intensity`** = Σ `emp_share_*` of manuf, construction, transport, accom_food, business_svc.

## 5. Variables EXCLUDED (full list, with reasons)

Considered and dropped. The first five were removed by the Stage-B filters above; the remaining
four were excluded by design before the PCA.

| Excluded variable | Source column | Reason for exclusion |
|---|---|---|
| Employee / wage-worker share | `lab_employee_count_y ÷ lab_working_pop_y` | Filter 2 — **empirical duplicate** of `formal_share` (r = 1.00) |
| Labor intensity | Σ labor-intensive `emp_share_*` | Filter 2 — **near-duplicate** of `manuf_share` (r = 0.89) |
| Written-contract share | `lab_contract_share_pct_y` | Filter 1 — **off-axis** (PC1 ≈ 0.06); loads on PC2 |
| Domestic-firm (PMDN) share | `ind_firms_pmdn_share_y` | Filter 1 — **off-axis** (PC1 ≈ 0.00); loads on PC2; also statistik-industri |
| Workers per firm / avg firm size | `ind_workers_per_firm_y` | Filter 1 — **off-axis / inert** (PC1 ≈ −0.06); loads on PC2 |
| Foreign-firm (PMA) share | `ind_firms_pma_share_y` | Near-mirror of PMDN (≈ sum to 100); user chose to keep neither ownership variable |
| Non-manufacturing share | `100 − emp_share_manuf_pct_y` | **Perfectly redundant** with `manuf_share` |
| Formal-worker headcount | `lab_formal_workers_y` | A **scale** measure, not intensity — would let province size dominate |
| PHK-target normalizer | `phk_y ÷ lab_formal_workers_y` | Belongs to the **validation** stage, not an index input |

> Data gaps noted but **not** in scope: share below minimum wage, low-education (≤ SD) share,
> union coverage — absent from the database.

## 6. Robustness (why the 2023 weights are treated as final)

**(A) Leave-one-out** — refit dropping each province in turn:
- Mean loading change **0.008**, max **0.047**. No single province moves the weights.
- Dropping **DKI Jakarta** shifts loadings ≤ 0.037 and leaves the ranking essentially identical
  (**Spearman = 0.9993**). The index is **not DKI-driven**.

**(B) 2024 refit** — same 5-variable PCA on 2024 (34 provinces):
- Still one dominant axis (PC1 = 62.8%). Loading-vector congruence **0.83**; ranking
  **Spearman 2023 vs 2024 = 0.875** (stable, with normal year-to-year movement).
- Four of five loadings near-identical; the one mover is **`bpjs_pu_share`** (0.47 → 0.36) —
  still positive and substantial, but the most year-sensitive input. Reinforces the design choice
  to **anchor on 2023 and apply the weights forward** rather than refit per year.

## 7. Interpretation of results

### 7.1 Full 10-variable PCA — two distinct axes

The full candidate PCA does not describe one thing; it describes **two**. PC1 (53.5%) and
PC2 (18.1%) split the variables cleanly:

- **PC1 = the formal / modern-sector gradient ("exposure").** Seven variables load positively at
  almost the same strength (~0.38–0.42): inverted-agriculture, employee share, formal share, BPJS
  coverage, services share, labor-intensity, and (partly) manufacturing. They co-move because they
  are all facets of *how industrialized and formalized a province is*. Inverted agriculture loads
  +0.42 because **low farming = high formal exposure** — the sharpest single marker of the gradient.
  DKI/Kepri/Banten sit at one end, Papua/NTT at the other.
- **PC2 = a firm-structure / employment-terms contrast (NOT exposure).** The three variables that
  are flat on PC1 define PC2: `pmdn_share` (+0.51) pulls against `contract_share` (−0.53),
  `workers_perfirm` (−0.43) and `manuf_share` (−0.40). Read together, PC2 separates **economies of
  many small domestic firms with few written contracts** (PC2 +) from **large, contract-based
  manufacturing economies** (PC2 −). This is real structural information about *what kind* of formal
  firms exist — a different question from *how much* of the workforce is formally exposed.

**Diagnosis:** `contract_share`, `pmdn_share`, and `workers_perfirm` carry ≈ zero exposure signal
(PC1 ≈ 0); they only describe PC2. `manuf_share` is split between the two axes (0.26 vs −0.40), which
dilutes its exposure weight. Averaging all ten therefore mixes two unrelated stories — the reason
PC1 reaches only 53%.

### 7.2 Final 5-variable PCA — one clean axis

Dropping the three off-axis variables and the two duplicates collapses everything onto a single
dimension: **PC1 = 74.4%** (+21 points). That rise means the five are consistent, mutually
reinforcing markers of one latent factor, so a single composite score is defensible.

| Variable | PC1 weight | Interpretation |
|---|---:|---|
| `agri_share` (inv) | 0.501 | **Strongest** discriminator — agriculture share ranges ~5% (DKI) to 50%+ (Sulbar/NTT), so "how un-agrarian" is the cleanest marker; anchors the low-exposure end |
| `formal_share` | 0.469 | Core direct measure of formal employment |
| `bpjs_pu_share` | 0.469 | Most literal count of workers who could file a recorded PHK/JKP claim |
| `services_share` | 0.469 | Modern urban-sector concentration |
| `manuf_share` | 0.299 | Contributes positively but weighs **least** (see below) |

- **The four ~0.47 weights are near-identical** because formality (formal share + BPJS) and
  modern-sector composition (high services + low agriculture) are effectively interchangeable ways
  of measuring the same gradient. The index behaves like a near-equal blend of those four, with a
  manufacturing tilt.
- **Manufacturing weighs least (0.30), and that is correct.** Exposure to *recorded* PHK is driven
  more by overall formalization than by factories: Bali and DIY rank high via services and formality
  with little manufacturing, while manufacturing-heavy Jawa Timur sits only mid-table (rank 21)
  because its formal share/services are moderate and its farm workforce still sizable. This confirms
  the index measures *recordable formality*, not industrial size.

### 7.3 What the province scores say

- **Top** — DKI Jakarta (100), Kepulauan Riau (89), Banten (79), Kalimantan Timur (72): the largest
  formal, recordable base — the biggest potential PHK "denominators."
- **Bottom** — Papua (0), NTT (25), Sulawesi Barat (27), Bengkulu (31): agrarian/informal, where
  layoffs are largely invisible to formal PHK statistics.
- **Key caution:** DKI = 100 does **not** mean highest layoff *warning*. It means DKI has the most
  formally-employed workers who *would show up* in recorded PHK if a shock hit. Whether a shock is
  coming is the job of Components 2–4; exposure is the stage on which that pressure would play out.

## 8. Caveats to carry forward

- **Single 2023 cross-section**; weights estimated from n = 34. Validation so far is only
  *concurrent*, not predictive — the leading (early-warning) property requires applying the
  weights across multiple years.
- Interpret scores as **relative** position ("most exposed among the 34"), not a probability or a
  calibrated threshold.
- 4 new Papua provinces are out of the 2023 sample (no structural data).
- **`bpjs_pu_share`** is the least year-stable input (see §6B).

## 9. Reproducing

```bash
Rscript model/model_LPI/LPI1_Labor_Exposure/01_lpi_component1_exposure.R
```

Reads `data/clean/phk_master.csv`; runs Stage A (full 10-var candidate PCA) and Stage B (final
5-var index); writes the three CSVs in `outputs/` and prints both robustness checks. No other
files are touched.

### Outputs
| File | Contents |
|---|---|
| `outputs/candidate_full_pca_loadings.csv` | All 10 candidates: PC1/PC2 loadings + keep/drop decision |
| `outputs/exposure_component1_loadings.csv` | Final 5-variable PC1 weights |
| `outputs/exposure_component1_2023_scores.csv` | 34-province exposure ranking (raw PC1 + 0–100) |
