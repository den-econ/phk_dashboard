#!/usr/bin/env Rscript
# ============================================================================
# 07_freeze_calibration.R  —  freeze the base-year (2025) LPI calibration
# ----------------------------------------------------------------------------
# The monthly LPI holds the structure pillars and the weights FIXED at the
# base year and moves only the pressure (LEI) input. To keep monthly scores
# comparable over time, we freeze FOUR things from the base year:
#   (1) each province's structural pillar scores (Pasar Kerja, Struktural),
#   (2) the standardisation centre/scale of all three pillars,
#   (3) the OECD weights,
#   (4) the 0-100 min/max bounds of the composite.
# Only the pressure pillar is recomputed each month (08_score_monthly.R).
#
# Inputs : outputs/models.rds, outputs/lei_annual.rds, outputs/lpi_composite.rds
# Output : outputs/lpi_calibration_<BASE>.rds
# Run from: model/model_LPI/   (after 02,03)
# ============================================================================
BASE <- 2025L
M   <- readRDS("outputs/models.rds")
agg <- readRDS("outputs/lei_annual.rds")$agg
LP  <- readRDS("outputs/lpi_composite.rds")
w   <- LP$res[[as.character(BASE)]]$w                 # frozen OECD weights (base year)

ls <- M$L9$E[[as.character(BASE)]]$score              # Pasar Kerja raw scores
es <- M$E5$E[[as.character(BASE)]]$score              # Struktural raw scores
lv <- setNames(agg$Indeks_LEI_Labour[agg$Tahun==BASE], agg$Provinsi[agg$Tahun==BASE]) # annual LEI
pv <- Reduce(intersect, list(names(ls), names(es), names(lv)))  # base-year scoreable set

# reproduce the base-year standardisation exactly (same as 03_weights_composite.R)
Z  <- scale(data.frame(Labour=as.numeric(ls[pv]), Econ=as.numeric(es[pv]),
                       Pressure=as.numeric(lv[pv])))
mu <- attr(Z,"scaled:center"); sdv <- attr(Z,"scaled:scale")
comp <- as.numeric(Z %*% w)
bounds <- c(min=min(comp), max=max(comp))

cal <- list(
  base_year   = BASE,
  provinces   = pv,                                   # scoreable provinces (need both structural pillars)
  struct_labour = setNames(as.numeric(ls[pv]), pv),   # frozen structural pillar 1 (raw)
  struct_econ   = setNames(as.numeric(es[pv]), pv),   # frozen structural pillar 2 (raw)
  mu = mu, sd = sdv,                                  # standardisation centre/scale (Labour,Econ,Pressure)
  weights = w,                                        # frozen OECD weights
  bounds = bounds,                                    # composite min/max for 0-100 rescale
  note = "monthly LPI = frozen structural + monthly LEI, standardised & weighted with these frozen params")

saveRDS(cal, sprintf("outputs/lpi_calibration_%d.rds", BASE))
cat(sprintf("froze %d-calibration: %d provinces\n", BASE, length(pv)))
cat("weights (Labour/Econ/Pressure): ", paste(round(w,3),collapse=" / "), "\n")
cat("Pressure centre/scale (annual LEI): ", round(mu[3],3), "/", round(sdv[3],3), "\n")
cat("composite bounds: ", round(bounds[1],3), " .. ", round(bounds[2],3), "\n")
