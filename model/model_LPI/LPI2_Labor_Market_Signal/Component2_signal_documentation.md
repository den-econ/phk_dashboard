# LPI Component 2 — Labor Market Signals (Sinyal Pasar Kerja)
### Scope (2023): current-slack signals only

**Layoff Pressure Index (LPI) · Indonesia PHK Early-Warning Dashboard**
Build script: [`01_lpi_component2_signal.R`](01_lpi_component2_signal.R) · Anchor year: **2023** · Grain: **province-year** · N = **34 provinces**

---

## 1. What this component is

Component 2 answers one clear question: **"how slack / weak is a province's labor market right
now?"** It is built from six current-level slack indicators — unemployment, under-employment,
part-time work, and Kemnaker registry flows (jobseekers, vacancies, placements). Higher score =
more slack = more layoff pressure.

## 2. Scope decision — momentum deferred (2026-07-15)

The originally-considered **momentum** variables (year-on-year growth / change of labor conditions)
are **set aside for now**, for two reasons:

1. **Momentum is not exposure and not slack — it is a *change*.** It does not belong in Component 1's
   structural exposure PCA (tested: adding momentum collapses that index from PC1 74% → 51%, and the
   momentum variables scatter onto a separate axis; a level and its own change correlate only r≈0.06).
2. **In a single 2023 cross-section, momentum is very noisy and volatile** — the momentum ranking's
   year-to-year stability was only Spearman ≈ 0.08 (it flips almost completely 2023→2024).

Since only 2023 data is available, Component 2 = **current-slack (Family B) only**. Momentum can
graduate into its own signal later, once several years of data make trends reliable.

## 3. Method — a transparent composite, not PCA

Even on the six slack signals alone, **PCA does not cohere** (PC1 ≈ 36%, and open unemployment loads
*opposite* to disguised under-utilisation — see §5). So we use the same transparent construction as
before:

1. **Orient** each signal so higher = more pressure (`-` variables sign-flipped ×−1).
2. **Standardize** (z-score) each signal across provinces.
3. **Equal-weight average** → the slack composite.

Provinces kept if ≥ 4 of 6 signals present (drops only the 4 new Papua provinces, which lack the
slack sub-indicators). Reported as raw z-average, a 0–100 rescale, and three **facet** sub-scores for
interpretation. **Recompute each year** (z-scored within the year); do not anchor-and-apply-forward.

## 4. Variables — the 6 current-slack signals

Orientation: **`+` = higher → more pressure; `−` = higher → less (sign-flipped before z-scoring).**
Facet = interpretive sub-grouping (not separate weights).

| Signal | Source column / formula | Facet | Dir |
|---|---|---|:--:|
| `lvl_tpt` | `lab_tpt_pct_y` | open unemployment | + |
| `lvl_jobseekers` | `1000 × lab_job_seekers_y ÷ lab_working_pop_y` *(derived)* | open unemployment | + |
| `lvl_underemp` | `lab_underemp_share_pct_y` | under-utilisation | + |
| `lvl_parttime` | `lab_part_time_share_pct_y` | under-utilisation | + |
| `lvl_vacancies` | `1000 × lab_vacancies_registered_y ÷ lab_working_pop_y` *(derived)* | labor demand | − |
| `lvl_placements` | `1000 × lab_placements_registered_y ÷ lab_working_pop_y` *(derived)* | labor demand | − |

*Machine-readable: [`outputs/signal_component2_variables.csv`](outputs/signal_component2_variables.csv).*

**Excluded — target / target-adjacent** (validation, not inputs): `phk_y`, `phk_flow`, `phk_stock`;
`bpjstk_phk_y`, `bpjstk_jkp_phk_y`, `bpjstk_jht_phk_y`.
**Deferred — momentum** (Family A): the YoY growth / vs-2019 change variables (see §2).

### 4.1 Justifikasi literatur — mengapa setiap variabel termasuk kelompok sinyal pasar kerja

**Konsep pemersatu: "kelonggaran pasar kerja / underutilisasi tenaga kerja" (labor market slack /
labor underutilization).** Seluruh kelompok ini bertumpu pada **kerangka underutilisasi tenaga kerja
ILO** (19th ICLS, 2013), yang secara formal mengakui bahwa tingkat pengangguran terbuka saja belum
menangkap kelemahan pasar kerja, dan mengelompokkan **pengangguran terbuka + setengah pengangguran
(underemployment) + potensi angkatan kerja** sebagai ukuran kelonggaran yang saling melengkapi. Keenam
variabel kita memetakan kerangka tersebut, ditambah **sisi permintaan tenaga kerja** (tradisi kurva
Beveridge / fungsi matching, di mana lowongan dan penempatan mengukur permintaan dan pertemuan pasar
kerja). Indikator-indikator ini bersifat **siklikal / kondisi terkini** — merespons siklus ekonomi dan
memberi sinyal pasar kerja yang *mendingin* — sehingga berbeda dari komposisi struktural yang
bergerak lambat pada Komponen 1.

- **ILO (2013).** *Resolution concerning statistics of work, employment and labour underutilization*, 19th ICLS.
- **ILO, Key Indicators of the Labour Market (KILM) / ILOSTAT.**
- **Hussmanns, Mehran & Verma (1990),** *Surveys of the Economically Active Population… An ILO Manual on Concepts and Methods.*

| Variabel | Mengapa termasuk sinyal/kelonggaran pasar kerja | Literatur kunci |
|---|---|---|
| **Tingkat pengangguran (TPT)** `lvl_tpt` | Ukuran kelonggaran utama — LU1 dalam kerangka ILO; indikator siklikal pasar kerja paling utama. Naiknya pengangguran terbuka adalah tanda klasik pasar kerja melemah. | ILO 19th ICLS (2013); ILO KILM/ILOSTAT |
| **Rasio pencari kerja terdaftar** `lvl_jobseekers` | Ukuran administratif tekanan pencarian kerja melalui layanan penempatan kerja publik (PES); naiknya pendaftaran menandai bertambahnya kelonggaran/aktivitas pencarian kerja. | Card, Kluve & Weber (2018), *JEEA* 16(3):894–931 (memakai data registrasi PES); tinjauan PES OECD; ILO Labour Market Information Systems |
| **Proporsi setengah pengangguran** `lvl_underemp` | Setengah pengangguran terkait waktu (LU2) — pekerja yang ingin/tersedia untuk jam kerja lebih banyak; ukuran kelonggaran inti di luar pengangguran, makin penting sejak 2008. | ILO 19th ICLS (2013); **Bell & Blanchflower (2021),** "Underemployment in the US and Europe," *ILR Review* 74(1):56–94 |
| **Proporsi pekerja paruh waktu** `lvl_parttime` | Kerja paruh waktu (terutama tak sukarela) meningkat saat permintaan melemah (pekerja terdorong di bawah jam kerja yang diinginkan) — sinyal kelonggaran siklikal. *(Catatan: variabel kita adalah paruh waktu total, proksi yang lebih bising daripada paruh waktu tak sukarela — lihat catatan di bawah.)* | **Valletta, Bengali & van der List (2020),** "Cyclical and Market Determinants of Involuntary Part-Time Employment," *J. Labor Economics* 38(1):67–93; Bell & Blanchflower (2021) |
| **Rasio lowongan kerja** `lvl_vacancies` | Indikator *permintaan* tenaga kerja; sisi lowongan pada kurva Beveridge. Lowongan lebih sedikit = permintaan lebih lemah = kelonggaran lebih besar (kebalikan dari ketatnya pasar kerja). | **Blanchard & Diamond (1989),** "The Beveridge Curve," *BPEA* 1989(1):1–76; **Elsby, Michaels & Ratner (2015),** "The Beveridge Curve: A Survey," *JEL* 53(3):571–630 |
| **Rasio penempatan tenaga kerja** `lvl_placements` | Penempatan PES = *keluaran fungsi matching* (perekrutan yang berhasil). Turunnya penempatan menandakan perekrutan/matching lebih lemah = kelonggaran lebih besar. | **Petrongolo & Pissarides (2001),** "Looking into the Black Box: A Survey of the Matching Function," *JEL* 39(2):390–431; Pissarides (2000), *Equilibrium Unemployment Theory* |

**Dua catatan yang jujur secara akademis:**
1. **Proporsi paruh waktu** — literatur mengaitkan paruh waktu *tak sukarela* dengan kelonggaran; variabel
   sumber kita adalah paruh waktu *total* (`lab_part_time_share_pct_y`), yang juga memuat paruh waktu
   sukarela. Jadi ini *proksi* — arahnya benar (Valletta dkk. 2020) tetapi lebih bising.
2. **Pencari kerja / lowongan / penempatan terdaftar** — ini adalah data *administratif* registri PES, bukan
   berbasis survei. Data administratif memiliki keterbatasan cakupan/perilaku registrasi dibanding ukuran
   survei (kehati-hatian umum dalam literatur data PES/LMIS) — karena itu kualitas data registri sudah kami
   tandai sebagai keterbatasan.

## 5. Interpretation of results (2023)

Full ranking: [`outputs/signal_component2_2023_scores.csv`](outputs/signal_component2_2023_scores.csv).

- **Highest slack:** Maluku, Aceh, Papua, NTB, Maluku Utara, NTT — high under-employment and/or weak
  labor demand.
- **Lowest slack (tight markets):** Kalimantan Utara, DKI Jakarta, Bali.
- **Signal ≠ Exposure (the key point).** This ranking is deliberately different from Component 1.
  DKI Jakarta is top on *exposure* but near the bottom on *slack* (rank 33) — a big formal workforce
  that was not slack in 2023. Exposure is the stage; slack is whether the play is starting.
- **Read the facets — they can disagree.** The three facets are only weakly related and sometimes
  *oppose* each other: open unemployment vs under-utilisation correlate **−0.47**. Economically
  sensible: where *open* unemployment is high, *disguised* under-employment tends to be lower (they
  are substitutes). Example: **DKI Jakarta** has high open unemployment (facet z = +1.06) but very low
  under-utilisation (−2.02), so its *net* slack is low. Always show the facet sub-scores alongside the
  headline so this nuance is visible.

## 6. Robustness

- **(A) Leave-one-signal-out:** drop each signal and re-rank — mean Spearman **0.86** (min 0.84).
  Robust, though with only 6 signals each one matters more than in a large basket.
- **(B) Facet correlations:** open vs under-utilisation **−0.47**, open vs demand −0.30, under vs
  demand +0.10 — the facets are largely independent (the composite averages them into a net-slack view).
- **(C) Year-to-year stability:** ranking Spearman 2023 vs 2024 = **0.72** — reasonably stable
  (slack levels persist), and a large improvement over the momentum-laden version (0.08). This confirms
  dropping momentum was the right call for a single-year build.

## 7. How the score is computed (worked example)

For each province: `slack_z = average over available signals of z(oriented signal)`, where
`z = (oriented value − mean) / sd` across provinces; equal weight `1/6` per signal. `slack_0_100`
rescales `100 × (slack_z − min) / (max − min)`. Facet sub-scores are the same average within each
facet's signals.

## 8. Caveats to carry forward

- **Registry data quality.** Jobseekers / vacancies / placements are Kemnaker administrative counts
  with uneven provincial coverage — a known limitation; included for now, to be reviewed.
- **Facet tension.** Open vs disguised unemployment move oppositely, so the equal-weight average is a
  *net* slack measure; the facet sub-scores carry the fuller story.
- **Annual, not monthly.** The "near-real-time monthly" ideal of lit-review Pillar 2 is not met at
  province-year grain.
- **Momentum deferred** (§2) — revisit as its own signal once multiple years are available.
- **4 new Papua provinces** excluded (lack the slack sub-indicators in 2023).

## 9. Methodology & references

### 9.1 How the equal-weight composite is constructed

A two-step construction — **normalize, then aggregate with equal weights.**

**Step 1 — Normalize (z-score).** Each of the 6 slack indicators is standardized across provinces:

```
z_ij = (x_ij − mean_j) / sd_j
```

where `x_ij` is province *i*'s value on indicator *j*. After this, every indicator has mean 0 and
SD 1, so a percentage (unemployment rate) and a per-1,000 rate (jobseekers) are comparable. **This
step is what makes equal weighting meaningful** — without it, the indicator with the largest raw
numbers would silently dominate.

**Step 2 — Aggregate with equal weights.** The composite is the arithmetic mean of the z-scores:

```
Slack_i = Σ_j w_j · z_ij ,   with  w_j = 1/6 ≈ 0.167 for every indicator j
```

so each indicator contributes equally *in standard-deviation units*.

Two subtleties:
- **Equal weighting is a deliberate choice, not "no weighting."** It encodes the judgment that there
  is no empirical or theoretical basis to rank one slack signal above another.
- **Nominal ≈ effective weights here.** When indicators are highly correlated, equal nominal weights
  secretly over-weight the correlated cluster (double-counting). Our signals are weakly correlated
  (mean |r| ≈ 0.24), so each exerts roughly independent, equal influence — a point *in favor* of
  equal weighting in this case.

### 9.2 Why not PCA (data-driven weights) for this component

PCA weighting lets the correlation structure choose the weights (PC1 loadings = weights). That is
valid only when indicators are strongly correlated and share one dominant common factor. For the
slack signals they do not:

| Check | LPI2 slack | LPI1 exposure (for contrast) |
|---|---|---|
| PC1 variance explained | 36% | 74% |
| Mean \|correlation\| | 0.24 | 0.7–0.9 |
| PC1 loading signs | contradictory | coherent |

Forcing PCA would (1) capture only ~36% of the information; (2) produce unstable, sample-specific
weights; (3) *suppress* the very facets we want represented (PCA down-weights indicators that do not
correlate with the majority — muting open-unemployment vs under-employment); and (4) misrepresent
genuinely distinct facets as one latent factor (the negative loadings are PCA signalling "not one
construct"). Standard suitability pre-checks agree: **Kaiser–Meyer–Olkin (KMO ≥ 0.6 rule of thumb)**
and **Bartlett's test of sphericity**, plus a "substantial" PC1 — LPI2 fails these, LPI1 passes.

**Consistent rule across the LPI:** use PCA when the data earns it (LPI1, strong common factor); use
an equal-weight composite when it does not (LPI2, heterogeneous weakly-correlated signals). The method
is chosen by the data structure and purpose.

### 9.3 Supporting literature

- **OECD & JRC (2008).** *Handbook on Constructing Composite Indicators: Methodology and User Guide.*
  Nardo, Saisana, Saltelli, Tarantola, Hoffman, Giovannini. — Authoritative reference: documents
  z-score normalization; states PCA/FA weighting is appropriate **only for correlated indicators**;
  notes **equal weighting is the most common scheme, used when there is no statistical/theoretical
  basis for differential weights**; warns statistically-derived weights can be counterintuitive/unstable.
- **Greco, Ishizaka, Tasiou & Torrisi (2019).** "On the Methodological Framework of Composite Indices:
  A Review of the Issues of Weighting, Aggregation, and Robustness." *Social Indicators Research*
  141(1): 61–94.
- **Decancq & Lugo (2013).** "Weights in Multidimensional Indices of Wellbeing: An Overview."
  *Econometric Reviews* 32(1): 7–34. — the correlated-indicators double-counting point.
- **Booysen (2002).** "An Overview and Evaluation of Composite Indices of Development."
  *Social Indicators Research* 59: 115–151.
- **Precedents using standardize-then-average (not PCA)** for heterogeneous signal baskets: The
  Conference Board **Leading Economic Index (LEI)**; OECD **Composite Leading Indicators (CLI)**; UNDP
  **Human Development Index** (equal weights by normative choice).

### 9.4 Interpreting this component within the full 4-pillar LPI

The four indicators play **different roles** and must **not** be simply averaged into one number:

- **LPI1 — Labor Exposure:** context / amplifier — *how much formal workforce is at stake* (the stage).
- **LPI2 — Labor Market Slack (this component):** current-conditions warning — *is the labor market
  already weakening now?* (near-coincident).
- **LPI3 — Domestic Economic Pressure:** broader macro / cost-pressure warning.
- **LPI4 — External Exposure:** global / trade risk.

Recommended combination (risk framework): **Risk = Exposure × Pressure** — keep Exposure (LPI1) as a
conditioning axis; combine the pressure signals (LPI2 + LPI3 + LPI4) into a Pressure score; present the
result as a **2-D Exposure × Pressure map** or a product. LPI2 is thus **one of the pressure signals** —
the "labor market is already slack" component. The alert zone is **high Exposure *and* high Pressure**:
a province with high slack (LPI2) *and* a large recordable formal base (LPI1) is where recorded PHK is
most likely to materialize and be visible; high slack with low exposure is a weaker warning (few
layoffs would be formally recorded).

**Two mechanical rules when combining:** (1) put all four pillars on a **common scale** (z-score or
0–100) and **orient all to "+risk"** before any aggregation — a PCA score (LPI1) and a composite
z-average (LPI2) cannot be added in native units; (2) decide the pillar-combination method deliberately
once all four exist (equal-weight pillars, validate-against-PHK weights, or the 2-D map — the last is
recommended).

## 10. Reproducing

```bash
Rscript model/model_LPI/LPI2_Labor_Market_Signal/01_lpi_component2_signal.R
```

Reads `data/clean/phk_master.csv`; runs Stage A (PCA diagnostic) and Stage B (slack composite); writes
the two CSVs in `outputs/` and prints all robustness checks. No other files are touched.

### Outputs
| File | Contents |
|---|---|
| `outputs/signal_component2_2023_scores.csv` | 34-province slack index: `slack_z`, `slack_0_100`, 3 facet sub-scores, rank |
| `outputs/signal_component2_variables.csv` | The 6 slack signals: facet, pressure direction, source column/formula |
