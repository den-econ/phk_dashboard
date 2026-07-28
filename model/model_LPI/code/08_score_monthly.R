#!/usr/bin/env Rscript
# ============================================================================
# 08_score_monthly.R  —  monthly LPI time series (province x month)
# ----------------------------------------------------------------------------
# For each (year, month) the LPI uses THAT YEAR's annual calibration — its own
# structural pillar scores (pasar_kerja, struktural) AND its own OECD weights,
# straight from 03/lpi_composite.rds. Only the pressure pillar varies month to
# month: tekanan = the LEI min-max'd across provinces WITHIN that month (the same
# standardisation used for the structural pillars). So monthly is simply a
# monthly-resolution version of that year's annual LPI.
#
# A year that has no annual calibration yet (e.g. 2026 before its labour/structure
# data lands) FALLS BACK to the latest available year (2025) — automatically, no
# manual setting. Once 2026 annual data is built, 2026 months use 2026.
#
# Inputs : outputs/lpi_composite.rds
#          ../model_LEI/data/Komposit_LEI_Ketenagakerjaan.xlsx (LEI Per Provinsi)
# Output : outputs/_xlsx_parts/06_monthly.csv  (the `monthly` sheet of lpi_scores.xlsx)
# Run from: model/model_LPI/   (after 03)
# ============================================================================
suppressMessages(library(readxl))
LP     <- readRDS("outputs/lpi_composite.rds"); res <- LP$res
availy <- sort(as.integer(names(res)))
FALLBACK <- max(availy)                 # latest year with an annual calibration
LEIX   <- "../model_LEI/data/Komposit_LEI_Ketenagakerjaan.xlsx"
cal_year <- function(y) if (y %in% availy) y else FALLBACK

# score one month, using calibration year `cy` (its structure + weights)
score <- function(cy, prov, lei) {
  r <- res[[as.character(cy)]]; pv <- names(r$s100)
  keep <- prov %in% pv; prov <- prov[keep]; lei <- lei[keep]
  pk <- as.numeric(r$pk[prov]); st <- as.numeric(r$st[prov]); w <- r$w
  tk <- 100*(lei - min(lei)) / (max(lei) - min(lei))   # min-max across provinces, within this month
  lpi <- w[1]*pk + w[2]*st + w[3]*tk
  data.frame(province=prov, pk=pk, st=st, tk=as.numeric(tk), lpi=as.numeric(lpi), row.names=NULL)
}

# ---- read monthly LEI ------------------------------------------------------
raw <- readxl::read_excel(LEIX, sheet="LEI Per Provinsi")
raw <- raw[!is.na(raw$Provinsi) & !is.na(raw$Tahun) & !is.na(raw$Bulan) &
           !is.na(raw$Indeks_LEI_Labour), ]

# ---- score each (year, month) with that year's calibration ----------------
# lpi_rank + 4 equal-count tiers are computed WITHIN each month (same as annual)
TIER_LAB <- c("Risiko Sangat Tinggi","Risiko Tinggi","Risiko Sedang","Risiko Rendah")  # G1 = highest
tier_of  <- function(s){ n<-length(s); rk<-rank(-s,ties.method="first")
  g<-ceiling(rk/(n/4)); g[g>4]<-4L; as.integer(g) }

key <- paste(raw$Tahun, raw$Bulan)
parts <- lapply(split(seq_len(nrow(raw)), key), function(ix) {
  y <- as.integer(raw$Tahun[ix][1]); m <- as.integer(raw$Bulan[ix][1])
  s <- score(cal_year(y), raw$Provinsi[ix], raw$Indeks_LEI_Labour[ix])
  s$year <- y; s$month <- m
  s$lpi_rank <- rank(-s$lpi, ties.method="first")
  g <- tier_of(s$lpi); s$tier <- g; s$tier_label <- TIER_LAB[g]
  s
})
mon <- do.call(rbind, parts)
mon <- mon[order(mon$year, mon$month, mon$lpi_rank), ]
mon <- mon[, c("year","month","province","lpi","pk","st","tk","lpi_rank","tier","tier_label")]
names(mon) <- c("year","month","province","lpi","pasar_kerja","struktural","tekanan",
                "lpi_rank","tier","tier_label")
for (c in c("lpi","pasar_kerja","struktural","tekanan")) mon[[c]] <- round(mon[[c]],1)

dir.create("outputs/_xlsx_parts", showWarnings=FALSE)
write.csv(mon, "outputs/_xlsx_parts/06_monthly.csv", row.names=FALSE)
cat(sprintf("scored %d province-months across %d months; calibration years: %s (fallback %d)\n",
            nrow(mon), length(unique(paste(mon$year,mon$month))),
            paste(availy,collapse=","), FALLBACK))

# ---- SELF-CHECK: each year's annual-mean LEI must reproduce its annual LPI --
ok <- TRUE
for (y in availy) {
  b   <- raw[raw$Tahun==y, ]
  ann <- aggregate(Indeks_LEI_Labour ~ Provinsi, data=b, FUN=mean)
  chk <- score(y, ann$Provinsi, ann$Indeks_LEI_Labour)
  ref <- res[[as.character(y)]]$s100
  mm  <- merge(chk, data.frame(province=names(ref), lpi_ref=as.numeric(ref)), by="province")
  d   <- max(abs(mm$lpi - mm$lpi_ref))
  cat(sprintf("  self-check %d: matched %d/%d, max abs diff = %.2g\n", y, nrow(mm), length(ref), d))
  ok <- ok && nrow(mm)==length(ref) && d < 1e-6
}
cat(if (ok) "OK — each year reproduces its annual LPI exactly.\n" else
             "WARNING — a year does not reproduce its annual LPI; inspect.\n")
