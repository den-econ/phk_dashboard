#!/usr/bin/env Rscript
# ============================================================================
# 07_freeze_calibration.R  —  freeze the base-year (2025) LPI calibration
# ----------------------------------------------------------------------------
# The LPI is a weighted sum of three 0-100 pillar scores. Monthly, the two
# structural pillars and the weights are held FIXED at the base year; only the
# pressure pillar moves. We freeze:
#   (1) each province's structural pillar 0-100 scores (Pasar Kerja, Struktural),
#   (2) the OECD weights.
# The monthly pressure score is NOT anchored to the base year — it is the LEI
# min-max'd across provinces within each month (the same standardisation used
# for the structural pillars), so it needs nothing frozen. See 08_score_monthly.R.
#
# Inputs : outputs/lpi_composite.rds
# Output : outputs/lpi_calibration_<BASE>.rds
# Run from: model/model_LPI/   (after 03)
# ============================================================================
BASE <- 2025L
LP   <- readRDS("outputs/lpi_composite.rds")
r    <- LP$res[[as.character(BASE)]]

cal <- list(
  base_year = BASE,
  provinces = names(r$s100),        # base-year scoreable set
  pk = r$pk,                        # frozen Pasar Kerja 0-100 (per province)
  st = r$st,                        # frozen Struktural 0-100 (per province)
  weights = r$w,                    # frozen OECD weights (PK, ST, TM)
  note = "monthly: pk/st/weights frozen at base year; tekanan = LEI min-max across provinces within each month (same as structure)")

saveRDS(cal, sprintf("outputs/lpi_calibration_%d.rds", BASE))
cat(sprintf("froze %d-calibration: %d provinces\n", BASE, length(cal$provinces)))
cat("weights (PK/ST/TM): ", paste(round(cal$weights,3),collapse=" / "), "\n")
