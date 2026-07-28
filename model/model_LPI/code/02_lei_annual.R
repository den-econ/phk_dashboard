#!/usr/bin/env Rscript
# ============================================================================
# 02_lei_annual.R  —  Tekanan Makroekonomi pillar: LEI monthly -> annual
# ----------------------------------------------------------------------------
# Input : ../model_LEI/data/Komposit_LEI_Ketenagakerjaan.xlsx
#         sheet "LEI Per Provinsi", column `Indeks_LEI_Labour`
#         (38 provinces x 48 months, 2022-2025 = 1824 rows)
# Output: outputs/lei_annual.rds   (province-year annual-mean LEI)
# Method: mean of the 12 monthly LEI values within each province-year.
#         This annual pressure score is the third LPI pillar, standardised
#         alongside the two vulnerability indices in 03_weights_composite.R.
# Run from: model/model_LPI/   (e.g.  Rscript code/02_lei_annual.R)
# ============================================================================
suppressMessages(library(readxl))
LEI_XLSX <- "../model_LEI/data/Komposit_LEI_Ketenagakerjaan.xlsx"
stopifnot(file.exists(LEI_XLSX))

raw <- readxl::read_excel(LEI_XLSX, sheet = "LEI Per Provinsi")
raw <- raw[!is.na(raw$Provinsi) & !is.na(raw$Tahun) & !is.na(raw$Indeks_LEI_Labour), ]

agg <- aggregate(Indeks_LEI_Labour ~ Provinsi + Tahun, data = raw, FUN = mean)
agg$Tahun <- as.integer(agg$Tahun)
agg <- agg[order(agg$Tahun, agg$Provinsi), ]
rownames(agg) <- NULL

dir.create("outputs", showWarnings = FALSE)
saveRDS(list(agg = agg), "outputs/lei_annual.rds")
cat(sprintf("LEI annual: %d rows, %d provinces x %d years\n",
            nrow(agg), length(unique(agg$Provinsi)), length(unique(agg$Tahun))))

# ---- verification against the persisted validated aggregation (if present) ----
if (file.exists("outputs/_lei_source.rds")) {
  ref <- readRDS("outputs/_lei_source.rds")$agg
  m <- merge(agg, ref, by = c("Provinsi", "Tahun"), suffixes = c(".new", ".ref"))
  d <- max(abs(m$Indeks_LEI_Labour.new - m$Indeks_LEI_Labour.ref))
  cat(sprintf("verify vs persisted: matched %d/%d rows, max abs diff = %.2e\n",
              nrow(m), nrow(ref), d))
  if (nrow(m) == nrow(ref) && d < 1e-9) cat("OK — reproduces persisted LEI annual exactly.\n") else
    cat("WARNING — differs from persisted values; inspect before using.\n")
}
