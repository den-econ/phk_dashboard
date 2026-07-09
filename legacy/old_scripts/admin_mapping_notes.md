# Admin mapping notes

How province names are standardized across the two source files, and the
decisions behind the 34 to 38 reconciliation. The machine-readable version is
`config/admin_mapping.yml`.

## The two naming systems

- The PHK workbook uses **38 provinces** in mixed case (for example `DKI Jakarta`,
  `DI Yogyakarta`, `Bangka Belitung`). This is the canonical set.
- MAP_composite_all uses **34 provinces** in UPPERCASE (for example
  `DKI JAKARTA`, `KEPULAUAN BANGKA BELITUNG`).
- The GeoJSON writes some names in full (for example
  `Daerah Istimewa Yogyakarta`).

All three are mapped to the canonical PHK spelling through the `aliases` table.

## The three kinds of difference

1. **Casing only.** `DKI JAKARTA` to `DKI Jakarta`, `DI YOGYAKARTA` to
   `DI Yogyakarta`. Handled by the alias table.
2. **Alias.** `Kepulauan Bangka Belitung` (MAP and GeoJSON) to `Bangka Belitung`
   (PHK). `Daerah Istimewa Yogyakarta` (GeoJSON) to `DI Yogyakarta`.
3. **Genuinely new provinces.** Four provinces exist in the PHK file but not in
   MAP: `Papua Selatan`, `Papua Tengah`, `Papua Pegunungan`, `Papua Barat Daya`.
   They split from old Papua and Papua Barat.

## Decisions

- The four new Papua provinces are kept as visible rows with
  `admin_mapping_status = new_province_no_map`. They are never folded into old
  Papua or Papua Barat. They also have no PHK data yet, so their PHK columns are
  empty and `phk_reporting_status = no_data`.
- MAP structural data ends in 2024. For 2025 the pipeline carries the 2024 MAP
  values forward and records the source year in `map_year_used`. This is an
  explicit, auditable assumption, not a silent fill.
- Where MAP and the PHK annual sheet share an indicator (UMP, TPT, informal,
  sector shares), the values agree once unit conventions are accounted for. UMP
  is in thousand IDR in the PHK sheet and IDR in MAP. Sector shares are fractions
  in the PHK sheet and percent in MAP. The master takes these indicators from the
  PHK sheet and uses MAP only for the composite score and the structural
  components PHK does not carry.
