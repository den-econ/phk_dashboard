#!/usr/bin/env Rscript
# ============================================================================
# 03_weights_composite.R  —  Stage-2 LPI: OECD factor-analysis weights + composite
# ----------------------------------------------------------------------------
# Inputs : outputs/models.rds       (validated pillar fits: $L9 labour, $E5 econ)
#          outputs/lei_annual.rds   (Tekanan Makroekonomi pillar; from 02)
# Outputs: outputs/lpi_composite.rds (per-year weights, loadings, composite s100)
#          outputs/lpi_weights_by_year.csv
#          outputs/lpi_weights.png   (stacked-bar chart, consumed by 04_report.R)
# Method : OECD-JRC Handbook (2008) sec 6.1 / Nicoletti et al. (2000):
#          standardise the 3 pillars -> correlation -> PCA -> retain m=2 factors
#          (eigenvalue >1 or "close to 1") -> varimax rotation ->
#          weight = (within-factor squared-loading share) x (factor variance share),
#          normalised to 100%. Composite = weighted sum of standardised pillars,
#          min-max rescaled to 0-100 within each year. PHK is never an input.
# Run from: model/model_LPI/
# ============================================================================
M   <- readRDS("outputs/models.rds")
agg <- readRDS("outputs/lei_annual.rds")$agg

oecd <- function(yr) {
  ls <- M$L9$E[[as.character(yr)]]$score          # Kerentanan Pasar Kerja
  es <- M$E5$E[[as.character(yr)]]$score           # Kerentanan Struktural Ekonomi
  lv <- setNames(agg$Indeks_LEI_Labour[agg$Tahun == yr], agg$Provinsi[agg$Tahun == yr]) # Tekanan
  pv <- Reduce(intersect, list(names(ls), names(es), names(lv)))
  Z  <- scale(data.frame(Labour = as.numeric(ls[pv]), Econ = as.numeric(es[pv]),
                         Pressure = as.numeric(lv[pv]))); rownames(Z) <- pv
  R  <- cor(Z); E <- eigen(R); m <- 2
  L  <- E$vectors[, 1:m] %*% diag(sqrt(E$values[1:m])); rownames(L) <- colnames(Z)
  Lr <- matrix(as.numeric(varimax(L)$loadings), 3, m,
               dimnames = list(colnames(Z), c("F1", "F2")))
  sq <- Lr^2; ev_r <- colSums(sq); fshare <- ev_r / sum(ev_r)
  within <- sweep(sq, 2, ev_r, "/"); a <- apply(sq, 1, which.max)
  raw <- sapply(1:3, function(i) within[i, a[i]] * fshare[a[i]]); w <- raw / sum(raw)
  comp <- as.numeric(Z %*% w)
  s100 <- setNames(100 * (comp - min(comp)) / (max(comp) - min(comp)), pv)
  list(N = length(pv), w = w, eig = E$values, fshare = fshare, Lr = Lr,
       within = within, assign = a, R = round(R, 3), raw = setNames(comp, pv), s100 = s100)
}

res <- lapply(2022:2025, oecd); names(res) <- 2022:2025
W <- do.call(rbind, lapply(names(res), function(y) data.frame(
  year = as.integer(y), N = res[[y]]$N,
  Labour   = round(100 * res[[y]]$w[1], 1),
  Econ     = round(100 * res[[y]]$w[2], 1),
  Pressure = round(100 * res[[y]]$w[3], 1),
  F1_share = round(100 * res[[y]]$fshare[1], 1),
  F2_share = round(100 * res[[y]]$fshare[2], 1))))

dir.create("outputs", showWarnings = FALSE)
saveRDS(list(res = res, W = W), "outputs/lpi_composite.rds")
write.csv(W, "outputs/lpi_weights_by_year.csv", row.names = FALSE)
cat("weights (Labour / Econ / Pressure), by year:\n"); print(W, row.names = FALSE)
cat(sprintf("mean: Labour %.1f  Econ %.1f  Pressure %.1f\n",
            mean(W$Labour), mean(W$Econ), mean(W$Pressure)))

# ---- stacked-bar weights chart (consumed by 04_report.R) ----
col <- c("#2b4a6f", "#2f7d75", "#c98a3a")
png("outputs/lpi_weights.png", width = 1580, height = 760, res = 150)
par(mar = c(3.2, 4, 2.2, 9.5), mgp = c(2.4, .7, 0))
mm <- t(as.matrix(W[, c("Labour", "Econ", "Pressure")])); colnames(mm) <- W$year
rownames(mm) <- c("Kerentanan Pasar Kerja", "Kerentanan Struktural", "Tekanan Makroekonomi")
bp <- barplot(mm, col = col, border = "white", ylab = "Weight (%)", las = 1,
              main = "OECD factor-analysis weights, by year", col.main = "#14181f",
              cex.main = 1, ylim = c(0, 100))
for (j in 1:ncol(mm)) { cum <- cumsum(mm[, j]); mid <- cum - mm[, j] / 2
  text(bp[j], mid, sprintf("%.0f%%", mm[, j]), col = "white", cex = .8, font = 2) }
par(xpd = NA); legend(par("usr")[2] * 1.02, 86, rev(rownames(mm)), fill = rev(col),
                      border = NA, bty = "n", cex = .72, title = "Indeks")
dev.off()
cat("saved outputs/lpi_composite.rds + lpi_weights_by_year.csv + lpi_weights.png\n")
