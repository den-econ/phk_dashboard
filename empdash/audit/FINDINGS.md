# empdash audit — running findings

Manual verification requested by Pak Arief (WA, 25 Jun & 1 Jul 2026):
1. recompute in Excel and compare against the dashboard
2. **check the shock calculation itself**, not only the employment result
3. **check that the code retrieves current data**
4. do it across the **whole 52×34 matrix**, not sector by sector

Audit branch: `muthia_cge`. Comparison target: `data/output/*.npy` written
2026-06-29 16:16 (T1 `2026M05`, T2 `WEO April 2026`, T3 `2026-05`).

---

## Status

| Phase | Scope | Status |
|---|---|---|
| 0 | Environment, provenance snapshot, CSV export | ✅ done |
| 1a | Theme 1 shocks — commodity prices | ✅ done |
| 1b | Theme 2 shocks — trading-partner growth | ⬜ not started |
| 1c | Theme 3 shocks — domestic demand | ⬜ not started |
| 2 | Full 52×34 reconstruction | ⬜ not started |
| 3 | Cell-by-cell comparison | ⬜ not started |
| 4 | Data-currency review | 🟡 partial |
| 5 | Excel workbook assembly | ⬜ not started |

---

## A. Arithmetic verification — everything checked so far reconciles exactly

**A1. The elasticity tensor is separable.** For all 38 × 52 (shock, sector)
pairs, `η_j[s,p] = intensity_j[s] × share[s,p]` holds to machine precision.
So the entire aggregation collapses to

```
E[s,p] = share[s,p] × Σ_j ( x_j × intensity_j[s] )
```

Reproduced end to end: max abs diff **2.7e-15** for `E`, **1.8e-11** for `ΔL`,
zero cells above 1e-9 across all 1,768. The Excel workbook therefore needs a
38×52 intensity table, one SUMPRODUCT and one outer product — not 38 matrices.

**A2. Theme 1 shocks reproduce exactly.** Rebuilt independently from
`wb_pinksheet.csv` using `x = YoY% − 48M trailing mean YoY%, lagged 1`:

| code | P(t) | P(t−12) | YoY% | trend48 | manual | dashboard | diff |
|---|---|---|---|---|---|---|---|
| cpo | 1139.94 | 907.58 | 25.60 | −2.96 | 28.5659 | 28.5659 | 0.0e+00 |
| coal | 136.86 | 104.41 | 31.08 | 6.32 | 24.7579 | 24.7579 | 0.0e+00 |
| nickel | 18805.77 | 15345.79 | 22.55 | −5.10 | 27.6464 | 27.6464 | 0.0e+00 |
| copper | 13543.19 | 9532.98 | 42.07 | 4.30 | 37.7667 | 37.7667 | 0.0e+00 |
| rubber | 2.21 | 1.70 | 30.00 | 2.81 | 27.1895 | 27.1895 | 0.0e+00 |
| oilgas | 100.43 | 62.75 | 60.05 | −1.07 | 61.1179 | 61.1179 | 0.0e+00 |
| electronics | — | — | — | — | 1.0168 | 1.0168 | 0.0e+00 |

FRED `IY3344` merges cleanly (245/245 observations matched) and is current
through 2026M05.

**No arithmetic error has been found in Theme 1.** The issues below are
methodological, not coding mistakes.

---

## B. Substantive findings

### B1. The three themes are on incompatible scales — T1 swamps the model

| theme | n | mean abs shock | max abs shock |
|---|---|---|---|
| T1 commodity | 7 | **29.72 pp** | 61.12 pp |
| T2 partner | 23 | **0.33 pp** | 0.93 pp |
| T3 domestic | 8 | **8.53 pp** | 28.78 pp |

Mean T1 shock is **91× larger** than mean T2. Base elasticities are similar
(0.20 / 0.15 / 0.10), so nothing offsets the gap, and T1 ends up driving
**92% of the total result** (`+479k` of `+520k` workers).

The cause is unit mismatch. A T1 shock is a deviation in *commodity price*
growth; a T2 shock is a deviation in *trading-partner GDP* growth. One pp of
price growth and one pp of GDP growth are not comparable economic events, yet
both are multiplied by elasticities of the same order. The dominance of T1 is
an artefact of unit choice, not of economics.

*Recommendation:* either normalise the shocks (e.g. standardise each theme, or
express all three in a common output-equivalent unit), or calibrate the base
elasticities so a shock of typical size in each theme produces a comparable
employment effect.

### B2. The layoff dashboard currently predicts job gains everywhere

Of 1,768 cells, 1,605 have non-zero employment. Of those:

- cells with **E < 0: zero**
- cells with **E > 0: 1,605**
- smallest positive value: `+0.000008%`
- net total: **+520,433 workers**

Every elasticity matrix is non-negative, and the large positive T1 shocks
reach all 52 sectors through the `0.05 × base` general-equilibrium spillover
term, so no cell can go negative while commodity prices are rising. An early-
warning tool for layoffs is currently showing employment growth in every
sector and every province.

This follows directly from B1 and is worth raising before the dashboard is
used for policy communication.

### B3. Linear extrapolation far outside plausible calibration range

`+61.12 pp × 0.20 = +12.2%` employment change in `OilGasGeo` from a single
shock, applied linearly. A CGE-derived elasticity is a local derivative; using
it 61 units away from the calibration point assumes linearity over a range
where it almost certainly does not hold. Same concern for `t3_ict_equipment`
at `+28.78 pp`.

### B4. Input data contains a violent one-month move — confirm it is real

Crude oil in the cached Pink Sheet jumps **$68.01 (2026M02) → $95.58
(2026M03)**, +40% in one month, then to $100.43 by 2026M05 (+60% YoY). The
shock computation handles this correctly, but the input itself should be
confirmed against the published Pink Sheet before the number is presented.

---

## C. Code and documentation defects

### C1. `TREND_WINDOW = 36` is dead code and contradicts the implementation

[`pipeline/config.py:72`](../pipeline/config.py#L72) declares
`TREND_WINDOW = 36  # months — same for Theme 1 and Theme 3`.

Neither `theme1_commodity.py` nor `theme3_domestic.py` imports `config` at all.
Both hardcode `rolling(48)`. The constant is never read anywhere in the
codebase.

The docstring of `compute_shocks` in
[`theme1_commodity.py:250-252`](../pipeline/ingestion/theme1_commodity.py#L250-L252)
also documents `YoY%_bar_36(t)` / "36-month trailing avg" while
[line 287](../pipeline/ingestion/theme1_commodity.py#L287) computes
`rolling(48)`. The module's own top docstring correctly says 48.

**Impact: none on results** — the code consistently uses 48. But three places
disagree about a headline methodological parameter, and the config constant
looks authoritative while being inert. Fix the docs; delete or wire up the
constant.

### C2. Source data is 32 days stale

All caches record `downloaded_at = 2026-06-25`; matrices written 2026-06-29;
today is 2026-07-27. The Pink Sheet cache carries the notice
"Updated on June 02, 2026" and ends at `2026M05`.

Directly relevant to ask (3). Needs a live check of what each source has
published since — pending in Phase 4.

### C3. SPE panel reports data through an unfinished year

`spe_meta.json` records `period_end = 2026-12` while the release vintage is
`April 2026`. Likely the Tabel 2 parser reading empty forward columns in the
BI workbook. To be confirmed in Phase 1c.

---

## D. Housekeeping

- `data/cache/theme1/*.xlsx` is gitignored ([.gitignore:20](../.gitignore#L20)),
  so the earlier manual workbooks `cpo_1pp_manual_check.xlsx` and
  `cpo_1pp_elasticity_build.xlsx` are **untracked** and would be lost on a
  fresh clone. They are audit deliverables and should live somewhere tracked.
- Stray Excel lock file `data/cache/theme1/~$wb_pinksheet.xlsx`.
- `data/cache/last_refresh.json` is gitignored, so refresh state is not
  recoverable from the repo.

---

# E. Deviasi dari instruksi build (`rawdata/claude_code_prompt.md`)

Sumber baru: prompt build asli. Ini mengubah gambaran — beberapa hal yang
tadinya terlihat sebagai pilihan desain ternyata **menyimpang dari instruksi
eksplisit**.

## E1. 🔴 Desain placeholder tidak mengikuti instruksi — dan ini penyebab B2

Prompt item 4 menyatakan desainnya secara sangat spesifik:

> *"Use the simplest possible placeholder. Do not introduce any data
> dependency beyond L⁰ for this... every cell is 0, except the 34 cells for
> sector k across all provinces. For those 34 cells, distribute a total of 1%
> across the provinces in proportion to each province's share of sector k's
> baseline employment."*

Jadi yang diminta: **satu shock → satu sektor**, sisanya **nol**.

Yang dibangun ([build_placeholders.py:67-94](../pipeline/elasticity/build_placeholders.py#L67-L94))
menambahkan dua lapisan yang tidak pernah diminta:

| lapisan | rumus | pasangan (shock,sektor) | porsi |
|---|---|---|---|
| direct | `base × intensitas × share` | 60 | 3,0% |
| **io_linked** | `0,30 × base × share` | 110 | 5,6% |
| **spillover** | `0,05 × base × share` | **1.806** | **91,4%** |
| nol | — | 0 | 0,0% |

**91,4% dari seluruh tensor adalah lapisan `spillover` yang seharusnya nol.**
Tidak ada satu pun sel bernilai nol, padahal prompt meminta mayoritas nol.

Kontribusinya terhadap hasil akhir:

| lapisan | ΔL | porsi |
|---|---|---|
| direct | +108.217 | 20,8% |
| io_linked | +94.556 | 18,2% |
| **spillover** | **+317.660** | **61,0%** |
| total | +520.433 | 100% |

**61% dari hasil dashboard berasal dari lapisan yang tidak diminta.**

Cakupannya: versi terbangun menyentuh **52/52 sektor** (1.605 sel non-nol);
versi sesuai prompt hanya **33/52 sektor**. Bahkan angka 33 ini masih terlalu
longgar — lapisan `direct` versi kode pun memberi beberapa sektor per shock
dengan intensitas tangan (mis. `t1_cpo` mengenai Estates 1,0 *dan* FoodMan
0,6), sedangkan prompt meminta satu sektor saja.

**Inilah akar penyebab temuan B2.** Karena `spillover` menyebarkan shock T1
yang besar dan positif ke seluruh 52 sektor, tidak ada sel yang bisa negatif.
Kalau desain prompt diikuti, sebagian besar sel akan nol dan hanya sektor
target yang bergerak.

Skala juga berbeda: prompt meminta total 1% per shock; kode memakai base
0,20 / 0,15 / 0,10.

## E2. 🔴 Tiga *correctness pitfall* tidak pernah di-enforce

Prompt item 3 meminta secara eksplisit:

> *"the percent-change formula bug warning in Theme 1, the yoy-not-mtm
> requirement in Theme 3, and the 36-month historical backfill requirement...
> Flag in your plan exactly where each of these gets enforced (e.g., as a unit
> test, an assertion, a backfill script)."*

Spec §4 Theme 1 bahkan menuliskan uji yang diminta: *"Enforce with a unit
test: a flat synthetic series must yield x_j = 0 exactly."*

**Tidak ada satu pun file test di repo.** Tidak ada `tests/`, tidak ada
`test_*.py`, tidak ada `conftest.py`, tidak ada assertion untuk ketiganya.

## E3. 🔴 `L0` tidak divalidasi, dan `.fillna(0)` menyembunyikan sel kosong

Prompt item 2:

> *"validate on load that it's actually 52×34, has no missing cells, and has
> no negative values, before it's used anywhere downstream."*

[`aggregation.py:_load_L0`](../pipeline/aggregation.py#L32-L45) tidak
memeriksa satupun dari ketiganya. Justru sebaliknya — `.fillna(0)` mengubah
sel kosong menjadi nol secara diam-diam, persis kebalikan dari "has no
missing cells". Sel kosong dan sel yang memang nol menjadi tak terbedakan.

Relevan: 163 dari 1.768 sel bernilai `L0 = 0`. Tidak ada cara membedakan
"sektor ini memang tidak ada di provinsi ini" dari "datanya hilang".

## E4. 🟡 Flag placeholder tidak pernah sampai ke pengguna

Prompt item 4:

> *"Every output that uses a placeholder elasticity should be visibly flagged
> as such (in code structure and ideally in any rendered output/metadata), so
> it's never confused with a real, CGE-calibrated result."*

`aggregation.py` memang menulis `"placeholder": true` ke
`aggregation_meta.json`. Tetapi kata `placeholder` **tidak muncul sama sekali**
di `dashboard/app.py`. Pengguna dashboard tidak diberi tahu bahwa seluruh
angka berasal dari elastisitas sintetis, bukan IndoTERM.

## E5. Ringkasan: spec / prompt vs kode

| Hal | Spec | Prompt | Kode |
|---|---|---|---|
| Rumus T1 | `100×(X_t−X_{t−1})/X_{t−1}` | ikut spec | `YoY% − rata2 48 bulan` |
| Jendela tren T3 | 36 bulan | 36 bulan (item 3) | **48 bulan** |
| Jumlah shock T1 | 8 | 8 | 7 |
| Jumlah shock T2 | ~17 | ~17 | 23 |
| Jumlah shock T3 | 52 | 52 | 8 |
| Total matriks | ~77 | ~77 | **38** |
| Struktur placeholder | — | 1 sektor, sisanya nol | 3 lapisan, 0 sel nol |
| Unit test | diminta | diminta | tidak ada |
| Validasi L0 | — | diminta | tidak ada |

Catatan: `TREND_WINDOW = 36` di `config.py` **cocok dengan spec dan prompt**.
Yang menyimpang adalah kode. Temuan C1 sebelumnya perlu dibaca ulang dengan
kerangka ini — itu bukan konstanta nganggur, itu nilai resmi yang ditimpa.

---

# F. Theme 2 — hasil audit

## F1. ✅ Aritmatika T2 cocok persis

Dibangun ulang secara independen dari dua vintage WEO dan bobot ekspor
Comtrade. Ketiga langkah diverifikasi:

| langkah | hasil |
|---|---|
| `d^g_c` = WEO Apr2026 − Apr2025 (tahun 2026) | 180 negara, cocok dgn `weo_revision_dgc.csv`, selisih maks **2,2e-16** |
| bobot `w_kc` berjumlah 1 per sektor | **30/30 sektor** ✓ |
| `x_k = Σ_c w_kc × d^g_c` | 23 sektor, selisih maks **1,1e-16** |

Tidak ada kesalahan aritmatika di Theme 2.

## F2. 🔴 BUG: Taiwan dibuang diam-diam dari seluruh perhitungan T2

UN Comtrade memberi kode Taiwan sebagai **`S19` "Other Asia, nes"**.
IMF WEO memberi kode **`TWN`**.

[`theme2_partner.py:159`](../pipeline/ingestion/theme2_partner.py#L159):

```python
w["d_g_c"] = w["country_iso"].map(d_g).fillna(0)
```

`S19` tidak ada di `d_g`, jadi `.fillna(0)` mengubah revisi Taiwan menjadi
**nol** tanpa peringatan apapun.

Padahal `TWN` **ada** di data WEO dengan revisi **+2,701 pp**, dan Taiwan
muncul di **22 dari 23 sektor tradable**, dengan bobot sampai 4,95%.

Dampak bila `S19` dipetakan ke `TWN`:

| sektor | x_k sekarang | x_k terkoreksi | perubahan |
|---|---|---|---|
| Coal | 0,2302 | 0,3639 | **+58%** |
| WoodProd | 0,1046 | 0,2308 | **+121%** |
| HortiCrops | −0,8780 | −0,7587 | +0,1193 |
| NonMetalProd | −0,1851 | −0,0897 | +0,0954 |
| BasicMetal | 0,3472 | 0,4377 | +0,0905 |
| CoalOilMan | 0,5144 | 0,5813 | +0,0669 |

Ekspor batu bara Indonesia ke Taiwan bernilai **USD 2,10 miliar** (Comtrade
2023) — bukan mitra kecil.

**Perbaikan:** tambahkan pemetaan kode `S19 → TWN` sebelum `.map()`, dan
ganti `.fillna(0)` yang membisu dengan peringatan yang mencatat negara mana
saja yang tidak ditemukan beserta total bobotnya.

## F3. 🟡 Cakupan bobot: sampai 5,2% dinolkan diam-diam

Di luar Taiwan, rata-rata **97,8%** bobot ekspor punya angka revisi WEO.
Terburuk `WoodProd` 94,8% — artinya 5,2% bobotnya menyumbang nol.

Mitra tanpa angka revisi (bobot terbesar): `S19` (0,4217 — Taiwan, lihat F2),
`LKA` Sri Lanka (0,0440), `TZA` Tanzania (0,0148), `LBN` Lebanon (0,0108).

Selain itu 43 negara ada di vintage 2026 tetapi tidak di vintage 2025,
sehingga terbuang saat `.dropna()` (223 → 180 negara).

## F4. 🟡 Satu negara mendominasi shock TranspEquip

Qatar direvisi **−14,22 pp** dengan bobot 3,08% di TranspEquip, menyumbang
**−0,438 pp** dari total `x_TranspEquip = −0,6667` — yaitu **66% shock sektor
itu berasal dari satu negara**. Bukan bug, tetapi rapuh: satu revisi ekstrem
di negara berbobot kecil bisa menggerakkan seluruh shock sektor.

(South Sudan direvisi −60,37 pp, tetapi bobotnya nol — tidak berdampak.)

## F5. Catatan proporsi

Bug F2 nyata dan besar **di dalam T2**, tetapi T2 sendiri hanya menyumbang
**+5.988 dari +520.433 pekerja (1,2%)** karena masalah skala di temuan B1.
Jadi memperbaiki Taiwan hampir tidak mengubah angka akhir dashboard —
sampai B1 diperbaiki lebih dulu. Keduanya perlu dilaporkan bersama.

---

# G. Theme 3 — hasil audit

## G1. ✅ Aritmatika T3 cocok persis

Dibangun ulang dari `spe_yoy_panel.csv` dengan `x_i = g_yoy − rata2 48
periode, lag 1`, memakai aturan dedup yang sama. Kesembilan kategori cocok
dengan **selisih maksimum 0,0e+00**.

Kodenya melakukan persis apa yang ditulisnya. Masalah di bawah ini ada pada
**data yang masuk**, bukan pada aritmatikanya.

## G2. 🔴 BUG: Juni–September hilang dari panel sejak 2022

Jumlah bulan per tahun di panel SPE:

| tahun | jumlah bulan | hilang |
|---|---|---|
| 2012–2020 | 12 | — |
| 2021 | 11 | Jun |
| 2022 | 9 | Jun, Jul, Agu |
| **2023** | **8** | **Jun, Jul, Agu, Sep** |
| **2024** | **8** | **Jun, Jul, Agu, Sep** |
| **2025** | **8** | **Jun, Jul, Agu, Sep** |
| 2026 | 5 | (berjalan) |

Sejak 2023, **sepertiga data tiap tahun hilang** dan tidak ada peringatan
apapun.

Dugaan penyebab: daftar nama bulan yang dipatok keras di
[`theme3_domestic.py:135`](../pipeline/ingestion/theme3_domestic.py#L135):

```python
MONTH_SHORT = ["Jan","Feb","Mar","Apr","Mei","Juni","Juli","Agst","Sept","Okt","Nov","Des"]
```

Indeks 6–9 (`Juni`, `Juli`, `Agst`, `Sept`) persis bulan-bulan yang hilang.
BI tampaknya mengubah format singkatan di file Excel-nya sekitar 2022
(mungkin ke `Jun`, `Jul`, `Ags`, `Sep`), dan pencocokan gagal diam-diam —
`next(..., None)` mengembalikan `None`, kolomnya dilewati tanpa error.

**Belum bisa dipastikan 100%** karena ZIP SPE sumber kena gitignore
(`data/cache/theme3/*.zip`) dan tidak ada di repo. Perlu unduh ulang untuk
konfirmasi.

### Akibatnya: jendela tren jadi jauh lebih panjang dari yang dimaksud

`rolling(48)` di pandas menghitung **48 baris**, bukan 48 bulan kalender.
Dengan hanya ~8 baris per tahun:

| | rentang |
|---|---|
| Jendela menurut spec | 36 bulan = **3,0 tahun** |
| Jendela yang dimaksud kode | 48 bulan = **4,0 tahun** |
| **Jendela sebenarnya** | 48 baris = **5,2 tahun** (2021-01 s/d 2026-04) |

73% lebih panjang dari niat kode. Dan ironisnya, docstring
[`theme1_commodity.py:17-18`](../pipeline/ingestion/theme1_commodity.py#L17-L18)
menyatakan 48 bulan dipilih justru untuk *"avoid post-crash bias"* — tetapi
karena bug ini jendelanya mundur sampai Januari 2021, **masuk jauh ke periode
distorsi COVID** yang ingin dihindari. Alasan yang ditulis dibatalkan oleh
bug parsing.

## G3. 🔴 Aturan dedup `keep="last"` tampaknya memilih nilai yang salah

Ada 18 pasangan (kategori, tanggal) berduplikat, semuanya di dua bulan
terakhir (2026-04 dan 2026-05). Kode mengambil baris terakhir
([`theme3_domestic.py:279-281`](../pipeline/ingestion/theme3_domestic.py#L279-L281))
dengan alasan *"last = latest BI revision"*.

Tetapi nilai yang diambil tidak konsisten dengan deret historisnya:

| kategori | 6 nilai sebelumnya | kandidat-1 | kandidat-2 (dipakai) |
|---|---|---|---|
| ict_equipment | −28,3 −27,4 −30,0 −27,1 −28,3 −26,4 | **−17,5** | **+8,9** |
| spare_parts | 12,0 17,7 14,8 7,4 13,1 15,5 | **16,6** | **+1,9** |
| cultural_rec | 6,7 8,1 5,2 15,9 10,1 14,8 | **0,6** | **−0,1** |

Pada ketiganya, **kandidat-1 jauh lebih konsisten** dengan riwayatnya.
`ict_equipment` melompat dari −26,4 ke +8,9 setelah 14 bulan bertahan di
sekitar −27 — lompatan 35pp yang tidak masuk akal untuk indeks ritel.

### Sensitivitas: pilihan ini mengubah hasil akhir 10,2%

| kategori | keep=last (sekarang) | keep=first | selisih |
|---|---|---|---|
| ict_equipment | 28,7833 | 2,9333 | **−25,85** |
| spare_parts | −1,2271 | 13,1500 | **+14,38** |
| sandang | 2,1042 | −4,9479 | **−7,05** |
| food_bev_tobacco | −6,4687 | −10,4688 | −4,00 |
| other_goods | 3,7646 | 1,3687 | −2,40 |

| | ΔL total |
|---|---|
| keep=last (sekarang) | **+520.433** pekerja |
| keep=first | **+467.533** pekerja |
| selisih | **−52.900 pekerja (−10,2%)** |

Jadi satu baris kode `keep="last"` menggeser hasil dashboard sebesar 52.900
pekerja. Ini juga berarti `t3_ict_equipment = +28,78pp` — shock T3 terbesar —
kemungkinan besar berasal dari kolom yang salah.

**Perlu konfirmasi dengan file sumber.** Unduh ulang ZIP SPE dan periksa tata
letak Tabel 2 untuk memastikan kolom mana yang benar-benar revisi terbaru.

## G4. 🟢 Anomali `period_end = 2026-12` — bug kosmetik saja

[`theme3_domestic.py:240-241`](../pipeline/ingestion/theme3_domestic.py#L240-L241)
mengambil `year.max()` dan `month.max()` **secara terpisah**:

```python
"period_end": f"{int(df['year'].max())}-{int(df['month'].max()):02d}"
```

`year.max()` = 2026, `month.max()` = 12 (dari Desember tahun lain) → `2026-12`.
Tanggal terakhir sesungguhnya 2026-05. Hanya salah tulis di metadata, tidak
mempengaruhi perhitungan. Perbaikan: pakai tanggal maksimum yang sebenarnya.

---

# H. Kelengkapan Theme 1

## H1. ✅ Ketujuh shock T1 yang ada di kode sudah diverifikasi

Keenam kolom Pink Sheet cocok dan lengkap sampai `2026M05`; `electronics`
dari FRED juga. Selisih terhadap dashboard **0,0e+00** untuk ketujuhnya.

| kode | observasi | NaN | terakhir |
|---|---|---|---|
| cpo | 797 | 0 | 2026M05 |
| coal | 677 | 120 | 2026M05 |
| nickel | 797 | 0 | 2026M05 |
| copper | 797 | 0 | 2026M05 |
| rubber | 329 | 468 | 2026M05 |
| oilgas | 797 | 0 | 2026M05 |

(NaN pada coal dan rubber hanya karena deretnya mulai lebih lambat secara
historis; jendela 48 bulan terakhir terisi penuh.)

## H2. 🔴 TGF (Textiles/garments/footwear) tidak pernah diimplementasikan

Spec §4 Theme 1 mendaftar **8 komoditas**; kode hanya punya **7**. Yang
hilang adalah **TGF**. Pencarian `tgf|garment|footwear` di seluruh
`pipeline/` dan `dashboard/` tidak menemukan apapun.

Spec menandainya *"demand-side, no single price — proxy needed (see Theme
2)"*, jadi memang perlu keputusan desain lebih dulu. Tetapi konsekuensinya
nyata: **Textiles adalah sektor padat karya** dan salah satu yang paling
rawan PHK. Saat ini Textiles hanya menerima shock lewat T2 (ekspor) dan T3
(sandang) — tidak ada jalur harga sama sekali.

Ini termasuk *open item* yang menurut prompt item 5 seharusnya diangkat
sebagai titik keputusan untuk Prof, bukan diselesaikan diam-diam.

## H3. 🟡 Pencocokan nama kolom Pink Sheet bersifat persis (rapuh)

[`theme1_commodity.py:106`](../pipeline/ingestion/theme1_commodity.py#L106)
mencocokkan judul kolom secara harfiah, termasuk `'Rubber, TSR20 **'` dengan
dua tanda bintang. Bila World Bank mengubah judul sedikit saja, kolom itu
tidak dikenali.

**Mitigasi yang sudah ada:** kegagalan tidak senyap — kolom yang tidak cocok
menghasilkan NaN, dan [`aggregation.py:98-100`](../pipeline/aggregation.py#L98-L100)
memasukkannya ke daftar `missing`. Status sekarang `missing = []`, jadi
keenam kolom cocok. Risiko ini lebih rendah daripada bug Taiwan (F2) yang
memang senyap.

---

# I. Kebaruan data (permintaan #3 Prof) — diperiksa langsung ke sumber

Diperiksa 2026-07-27 (catatan: file World Bank yang diunduh bertanggal
"Updated on August 04, 2026").

## I1. 🔴 BUG KRITIS: deteksi Pink Sheet berbasis-URL tidak akan pernah bekerja

[`theme1_commodity.py:141-143`](../pipeline/ingestion/theme1_commodity.py#L141-L143):

```python
if current_url == cached_url and os.path.exists(csv_path):
    log("  No new Pink Sheet (URL unchanged)")
    return _load_cached_pinksheet(csv_path)
```

Docstring modul menyatakan *"URL discovered by scraping the WB commodity-
markets page — hash changes each update."*

**Asumsi itu salah.** Diverifikasi langsung:

| | URL |
|---|---|
| cache (25 Jun) | `...6b9e4e-0050012026/related/CMO-Historical-Data-Monthly.xlsx` |
| live (27 Jul) | `...6b9e4e-0050012026/related/CMO-Historical-Data-Monthly.xlsx` |

**Identik.** Tetapi isinya berbeda:

| | catatan di file | data sampai |
|---|---|---|
| cache | Updated on **June 02, 2026** | 2026M05 (797 baris) |
| live | Updated on **August 04, 2026** | **2026M07** (799 baris) |

World Bank memperbarui file **di tempat pada URL yang sama**. Karena kode
hanya membandingkan URL, ia akan **selamanya** melaporkan "tidak ada update".

**Data yang terlewat: 2026M06 dan 2026M07.**

**Perbaikan:** bandingkan isi, bukan URL — misalnya `Last-Modified` /
`ETag` dari HTTP HEAD, hash isi file, atau baris "Updated on ..." di dalam
file.

## I2. 🔴 Parser tidak bisa membaca format Pink Sheet yang sekarang

Andaikan unduhan tetap terjadi, `_parse_pinksheet` akan gagal.
[Baris 82-89](../pipeline/ingestion/theme1_commodity.py#L82-L89) mencari
baris header yang memuat `"period"` atau `"Date"`:

```python
if any("period" in str(v).lower() or str(v).strip() == "Date" ...):
```

Struktur file live sekarang:

| baris | kolom 0 |
|---|---|
| 3 | `Updated on August 04, 2026` |
| 4 | *(kosong — baris ini berisi nama komoditas)* |
| 5 | *(kosong — baris satuan)* |
| 6 | `1960M01` |

**Tidak ada sel berisi "period" atau "Date" di seluruh 72 kolom.** Pencarian
mengembalikan `None` → `ValueError("Cannot find header row in Pink Sheet")`.

Jadi ada dua kegagalan berlapis: unduhan tidak pernah dipicu (I1), dan
seandainya dipicu pun akan error (I2).

## I3. 🔴 Dampak: hasil dashboard terlalu tinggi 33,7%

Shock T1 dihitung ulang memakai data terkini (s/d 2026M07):

| komoditas | dashboard (2026M05) | data terkini (2026M07) | perubahan |
|---|---|---|---|
| cpo | 28,57 | 16,97 | −11,60 |
| coal | 24,76 | 18,37 | −6,39 |
| nickel | 27,65 | 17,16 | −10,49 |
| copper | 37,77 | 32,35 | −5,42 |
| rubber | 27,19 | 23,03 | −4,16 |
| **oilgas** | **61,12** | **17,44** | **−43,68** |
| jumlah | +207,04 | +125,31 | **−81,74 pp** |

| | ΔL total |
|---|---|
| data cache (ditampilkan sekarang) | **+520.433** pekerja |
| data terkini | **+344.865** pekerja |
| selisih | **−175.568 pekerja (−33,7%)** |

Lonjakan minyak yang jadi sorotan temuan B4 ternyata **sudah berbalik**:
harga turun dari $100,43 (2026M05) ke $79,80 (2026M07), dan shock-nya runtuh
dari +61,12 ke +17,44 pp. Dashboard masih menampilkan puncak yang sudah lewat
dua bulan.

## I4. 🟡 `FCAST_YR = 2026` dipatok keras — akan usang sendiri

[`theme2_partner.py:30`](../pipeline/ingestion/theme2_partner.py#L30).
Shock T2 adalah revisi ramalan untuk tahun **2026**. Per Juli 2026, 2026
adalah tahun **berjalan**, bukan ramalan. Mulai 2027 ini menjadi revisi
terhadap tahun yang sudah lewat — tidak bermakna sebagai sinyal permintaan ke
depan. Perlu bergeser otomatis.

## I5. 🟡 Label vintage WEO diambil dari waktu kode berjalan, bukan waktu rilis IMF

[`theme2_partner.py:122-123`](../pipeline/ingestion/theme2_partner.py#L122-L123):

```python
new_id = f"{now.year}{now.month:02d}"
```

lalu label ditentukan `'April' if release_month <= 6 else 'October'`.

Jika vintage baru terdeteksi pada Juli, ia dicap `202607` → dilabeli
**"WEO October 2026"**, padahal IMF merilisnya pada April. Label salah, dan
dua vintage yang terdeteksi di bulan berbeda dari rilis yang sama akan
tercatat sebagai dua vintage berbeda.

## I6. 🟡 Ambang `> 0.05` untuk mendeteksi vintage baru bisa keliru dua arah

[`theme2_partner.py:77`](../pipeline/ingestion/theme2_partner.py#L77)
menyatakan rilis WEO baru bila rata-rata selisih 7 negara kunci > 0,05 pp.

- **Negatif palsu:** rilis baru yang kebetulan hanya sedikit mengubah ketujuh
  negara itu tidak terdeteksi.
- **Positif palsu:** DataMapper merevisi angka tanpa rilis WEO baru → tercatat
  sebagai vintage baru, dan "revisi" yang dihitung hanyalah derau.

## I7. Belum bisa diperiksa dari lingkungan ini

| sumber | status |
|---|---|
| World Bank Pink Sheet | ✅ diperiksa — lihat I1–I3 |
| IMF DataMapper | ❌ HTTP 403 dari lingkungan ini |
| Bank Indonesia (SPE) | ❌ koneksi diputus |

Keduanya perlu diperiksa Muthia dari jaringan biasa. Yang perlu dipastikan:
apakah WEO Oktober 2026 sudah terbit, dan apakah SPE Juni/Juli 2026 sudah
tersedia (cache berhenti di rilis April 2026).

Catatan tambahan: `_probe_latest` di T3 hanya mundur **4 bulan**
([`theme3_domestic.py:87`](../pipeline/ingestion/theme3_domestic.py#L87)).
Bila pipeline tidak dijalankan lebih dari 4 bulan, ia tidak akan menemukan
rilis apapun dan diam-diam memakai cache lama.
