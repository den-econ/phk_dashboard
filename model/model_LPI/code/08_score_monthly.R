#!/usr/bin/env Rscript
# ============================================================================
# 08_score_monthly.R  —  monthly LPI using the frozen base-year calibration
# ----------------------------------------------------------------------------
# Produces a province x month LPI time series. LPI = weighted sum of three
# 0-100 pillar scores. Monthly, the two structural pillar scores and the weights
# are held frozen at the base year (07_freeze_calibration.R); only the pressure
# pillar moves — each month's LEI is rescaled to 0-100 against the frozen
# base-year LEI range. Scores stay comparable month to month; a month's pressure
# (hence LPI) can fall outside the base range (kept, not clamped — informative).
#
# Inputs : outputs/lpi_calibration_<BASE>.rds
#          ../model_LEI/data/Komposit_LEI_Ketenagakerjaan.xlsx (LEI Per Provinsi, monthly)
# Outputs: outputs/lpi_monthly.csv
#          outputs/_xlsx_parts/06_monthly.csv  (becomes the `monthly` sheet in lpi_scores.xlsx)
# Self-check: feeding the base-year ANNUAL-MEAN LEI must reproduce the base-year
#            annual LPI (outputs/lpi_composite.rds s100). Fails loudly otherwise.
# Run from: model/model_LPI/   (after 07)
# ============================================================================
suppressMessages(library(readxl))
BASE <- 2025L
cal  <- readRDS(sprintf("outputs/lpi_calibration_%d.rds", BASE))
LEIX <- "../model_LEI/data/Komposit_LEI_Ketenagakerjaan.xlsx"

# score one set of (province -> LEI value) with the frozen calibration
# LPI = w_PK*PK + w_ST*ST + w_TM*TM, where PK/ST are frozen 0-100 and TM is the
# month's LEI rescaled 0-100 against the frozen base-year LEI range.
score <- function(prov, lei) {
  keep <- prov %in% cal$provinces
  prov <- prov[keep]; lei <- lei[keep]
  pk <- as.numeric(cal$pk[prov]); st <- as.numeric(cal$st[prov])
  tk <- 100*(lei - cal$lei_min) / (cal$lei_max - cal$lei_min)   # pressure 0-100 (may exceed range)
  lpi <- cal$weights[1]*pk + cal$weights[2]*st + cal$weights[3]*tk
  data.frame(province=prov, pk=pk, st=st, tk=as.numeric(tk), lpi=as.numeric(lpi), row.names=NULL)
}

# ---- read monthly LEI ------------------------------------------------------
raw <- readxl::read_excel(LEIX, sheet="LEI Per Provinsi")
raw <- raw[!is.na(raw$Provinsi) & !is.na(raw$Tahun) & !is.na(raw$Bulan) &
           !is.na(raw$Indeks_LEI_Labour), ]

# ---- score every province-month -------------------------------------------
key <- paste(raw$Tahun, raw$Bulan)
parts <- lapply(split(seq_len(nrow(raw)), key), function(ix) {
  s <- score(raw$Provinsi[ix], raw$Indeks_LEI_Labour[ix])
  s$year <- as.integer(raw$Tahun[ix][1]); s$month <- as.integer(raw$Bulan[ix][1]); s
})
mon <- do.call(rbind, parts)
mon <- mon[order(mon$year, mon$month, -mon$lpi), ]
mon <- mon[, c("year","month","province","lpi","pk","st","tk")]
names(mon) <- c("year","month","province","lpi_0_100",
                "pasar_kerja_0_100","struktural_0_100","tekanan_0_100")
for (c in c("lpi_0_100","pasar_kerja_0_100","struktural_0_100","tekanan_0_100"))
  mon[[c]] <- round(mon[[c]],1)
write.csv(mon, "outputs/lpi_monthly.csv", row.names=FALSE)

# stage the monthly table as a workbook part so lpi_scores.xlsx gains a `monthly`
# sheet — 05b_build_xlsx.py packages every outputs/_xlsx_parts/*.csv into the xlsx.
dir.create("outputs/_xlsx_parts", showWarnings=FALSE)
write.csv(mon, "outputs/_xlsx_parts/06_monthly.csv", row.names=FALSE)

cat(sprintf("scored %d province-months across %d months (%d provinces)\n",
            nrow(mon), length(unique(paste(mon$year,mon$month))), length(cal$provinces)))

# ---- SELF-CHECK: annual-mean LEI must reproduce base-year annual LPI --------
b <- raw[raw$Tahun==BASE, ]
ann <- aggregate(Indeks_LEI_Labour ~ Provinsi, data=b, FUN=mean)
chk <- score(ann$Provinsi, ann$Indeks_LEI_Labour)
ref <- readRDS("outputs/lpi_composite.rds")$res[[as.character(BASE)]]$s100
m <- merge(chk, data.frame(province=names(ref), lpi_ref=as.numeric(ref)), by="province")
d <- max(abs(m$lpi - m$lpi_ref))
cat(sprintf("self-check vs %d annual LPI: matched %d/%d provinces, max abs diff = %.3g\n",
            BASE, nrow(m), length(ref), d))
if (nrow(m)==length(ref) && d < 1e-6) cat("OK — reproduces base-year annual LPI exactly.\n") else
  cat("WARNING — monthly machinery does not reproduce the annual LPI; inspect.\n")
