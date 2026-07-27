#!/usr/bin/env Rscript
# ============================================================================
# 07_freeze_calibration.R  —  freeze the base-year (2025) LPI calibration
# ----------------------------------------------------------------------------
# The LPI is a weighted sum of three 0-100 pillar scores. Monthly, the two
# structural pillars and the weights are held FIXED at the base year; only the
# pressure pillar moves. To keep monthly scores comparable, we freeze:
#   (1) each province's structural pillar 0-100 scores (Pasar Kerja, Struktural),
#   (2) the OECD weights,
#   (3) the base-year LEI min & max, used to rescale each month's LEI to 0-100.
# Monthly pressure score = 100*(LEI_month - lei_min)/(lei_max - lei_min).
#
# Inputs : outputs/models.rds, outputs/lei_annual.rds, outputs/lpi_composite.rds
# Output : outputs/lpi_calibration_<BASE>.rds
# Run from: model/model_LPI/   (after 02,03)
# ============================================================================
BASE <- 2025L
M   <- readRDS("outputs/models.rds")
agg <- readRDS("outputs/lei_annual.rds")$agg
LP  <- readRDS("outputs/lpi_composite.rds")
r   <- LP$res[[as.character(BASE)]]
w   <- r$w                                            # frozen OECD weights (base year)
pv  <- r$N; pv <- names(r$s100)                       # base-year scoreable set

lv  <- setNames(agg$Indeks_LEI_Labour[agg$Tahun==BASE], agg$Provinsi[agg$Tahun==BASE])[pv]

cal <- list(
  base_year = BASE,
  provinces = pv,
  pk = r$pk,                                          # frozen Pasar Kerja 0-100 (per province)
  st = r$st,                                          # frozen Struktural 0-100 (per province)
  weights = w,                                        # frozen OECD weights (PK, ST, TM)
  lei_min = min(as.numeric(lv)),                      # base-year LEI range -> rescales monthly LEI to 0-100
  lei_max = max(as.numeric(lv)),
  note = "LPI = w_PK*PK + w_ST*ST + w_TM*TM ; monthly TM = 100*(LEI-lei_min)/(lei_max-lei_min)")

saveRDS(cal, sprintf("outputs/lpi_calibration_%d.rds", BASE))
cat(sprintf("froze %d-calibration: %d provinces\n", BASE, length(pv)))
cat("weights (PK/ST/TM): ", paste(round(w,3),collapse=" / "), "\n")
cat(sprintf("base-year LEI range: %.3f .. %.3f\n", cal$lei_min, cal$lei_max))
