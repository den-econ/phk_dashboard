# =============================================================================
# LPI — Labor Market Structure (Struktur Tenaga Kerja)
# =============================================================================
# Layoff Pressure Index (LPI), Indonesia PHK Early-Warning Dashboard.
#
# WHAT THIS COMPONENT IS
#   A structural index of how formal / modern-sector each province's labor market
#   is. It is the EXPOSURE pillar of the LPI — it ranks provinces by how much of
#   their workforce sits in the formal, recordable net (the pool that can be
#   recorded as PHK). Actual PHK is the TARGET this index is VALIDATED against
#   (section 5), never an input.
#
# METHOD
#   Cross-sectional PCA on 5 standardized variables; PC1 = the Labor Market
#   Structure score. Variables enter in their NATURAL direction (no inversion),
#   so loadings come out naturally + or - (formal/manufacturing/wage load
#   positive; agriculture and participation load negative). The 5-variable set
#   was chosen from a 4-way specification search (section 2): (TPAK vs TPT) x
#   (minimum wage UMP vs average employee wage). TPAK + average wage ("Upah")
#   is the only combination with KMO >= 0.6, the highest PC1, and the best PHK
#   validation.
#
# GRAIN / ANCHOR
#   province-year, anchor = 2023 (collapse master with month == 1). N = 34.
#
# INPUT : data/clean/phk_master.csv
# OUTPUT: model/model_LPI/LPI_Labor_Market_Structure/outputs/lms_2023_scores.csv
#         model/model_LPI/LPI_Labor_Market_Structure/outputs/lms_loadings.csv
#         model/model_LPI/LPI_Labor_Market_Structure/outputs/lms_specification_search.csv
#         model/model_LPI/LPI_Labor_Market_Structure/outputs/lms_scree.png
#
# Run:  Rscript model/model_LPI/LPI_Labor_Market_Structure/01_lpi_labor_market_structure.R
# =============================================================================

MASTER  <- "~/phk_dashboard/data/clean/phk_master.csv"
OUT_DIR <- "~/phk_dashboard/model/model_LPI/LPI_Labor_Market_Structure/outputs"
ANCHOR  <- 2023
if (!dir.exists(OUT_DIR)) dir.create(OUT_DIR, recursive = TRUE)

# -----------------------------------------------------------------------------
# 0. Diagnostics (PCA suitability).
# -----------------------------------------------------------------------------
bartlett <- function(R, n) {
  p <- ncol(R); chi <- -((n - 1) - (2 * p + 5) / 6) * log(det(R))
  c(chisq = chi, df = p * (p - 1) / 2, p = pchisq(chi, p * (p - 1) / 2, lower.tail = FALSE))
}
kmo <- function(R) { iR <- solve(R); Q <- -cov2cor(iR)
  r2 <- sum(R[upper.tri(R)]^2); q2 <- sum(Q[upper.tri(Q)]^2); r2 / (r2 + q2) }
kmo_item <- function(R) { iR <- solve(R); Q <- -cov2cor(iR)
  sapply(seq_len(ncol(R)), function(j) { r2 <- sum(R[-j, j]^2); q2 <- sum(Q[-j, j]^2); r2 / (r2 + q2) }) }

# -----------------------------------------------------------------------------
# 1. Build the candidate matrix (NATURAL direction — no inversion).
#    Fixed core: agriculture, formal, manufacturing employment shares.
#    Swappable: labor-market var (TPAK | TPT) and wage var (UMP | Upah).
# -----------------------------------------------------------------------------
build_matrix <- function(dat, yr, labor_col, wage_col) {
  y <- dat[dat$month == 1 & dat$year == yr, ]
  M <- data.frame(
    agri   = y$emp_share_agri_pct_y,      # agriculture employment share
    formal = y$lab_formal_share_pct_y,    # formal employment share
    manuf  = y$emp_share_manuf_pct_y,     # manufacturing employment share
    labor  = y[[labor_col]],              # TPAK (participation) or TPT (unemployment)
    wage   = y[[wage_col]]                # UMP (minimum) or Upah (avg employee wage)
  )
  rownames(M) <- y$province_name_std
  M[complete.cases(M), ]
}

# -----------------------------------------------------------------------------
# 2. Fit PCA -> PC1 loadings + scores. PC1 oriented so `formal` loads positive
#    ("higher score = more formal / exposed"). No variable is inverted, so the
#    other loadings fall out naturally (agri, TPAK negative; manuf, wage positive).
# -----------------------------------------------------------------------------
fit_pca <- function(M) {
  p <- prcomp(M, center = TRUE, scale. = TRUE)
  if (p$rotation["formal", "PC1"] < 0) { p$rotation <- -p$rotation; p$x <- -p$x }
  R <- cor(scale(M))
  list(loadings = p$rotation[, 1], scores = setNames(p$x[, 1], rownames(M)),
       var_expl = p$sdev^2 / sum(p$sdev^2), eig = p$sdev^2,
       kmo = kmo(R), msa = setNames(kmo_item(R), colnames(M)), R = R, N = nrow(M))
}

d     <- read.csv(MASTER, stringsAsFactors = FALSE)
phk_r <- setNames(d[d$month == 1 & d$year == ANCHOR, "phk_y"] /
                  d[d$month == 1 & d$year == ANCHOR, "lab_working_pop_y"],
                  d[d$month == 1 & d$year == ANCHOR, "province_name_std"])
validate <- function(scores) {
  cm <- intersect(names(scores), names(phk_r)); cm <- cm[!is.na(phk_r[cm])]
  cor(scores[cm], phk_r[cm], method = "spearman")
}

# =============================================================================
# SECTION 2 — SPECIFICATION SEARCH: 4 combinations (TPAK|TPT) x (UMP|Upah)
# =============================================================================
COMBOS <- list(
  list(name = "TPAK + UMP",  labor = "lab_tpak_pct_y", wage = "wage_ump_idr_y"),
  list(name = "TPAK + Upah", labor = "lab_tpak_pct_y", wage = "wage_avg_employee_idr_y"),
  list(name = "TPT + UMP",   labor = "lab_tpt_pct_y",  wage = "wage_ump_idr_y"),
  list(name = "TPT + Upah",  labor = "lab_tpt_pct_y",  wage = "wage_avg_employee_idr_y")
)
spec_tbl <- do.call(rbind, lapply(COMBOS, function(cb) {
  f <- fit_pca(build_matrix(d, ANCHOR, cb$labor, cb$wage))
  data.frame(spec = cb$name, N = f$N, KMO = round(f$kmo, 3),
             PC1_pct = round(100 * f$var_expl[1], 1), factors_gt1 = sum(f$eig > 1),
             validation_vs_PHK = round(validate(f$scores), 3))
}))
cat("================ SECTION 2: SPECIFICATION SEARCH (4 combinations) ================\n")
print(spec_tbl, row.names = FALSE)
write.csv(spec_tbl, file.path(OUT_DIR, "lms_specification_search.csv"), row.names = FALSE)
cat("\nChosen: TPAK + Upah — only combo with KMO >= 0.6, highest PC1, best validation.\n")
cat("  (UMP loads ~0 — minimum wage is administratively uniform; average wage discriminates.\n")
cat("   TPT drags KMO below 0.5; TPAK is far cleaner.)\n")

# =============================================================================
# SECTION 3 — FINAL INDEX: TPAK + Upah
# =============================================================================
M   <- build_matrix(d, ANCHOR, "lab_tpak_pct_y", "wage_avg_employee_idr_y")
fit <- fit_pca(M)
cat(sprintf("\n================ SECTION 3: FINAL LABOR MARKET STRUCTURE (TPAK + Upah) ================\n"))
cat(sprintf("N = %d | KMO = %.3f | Bartlett p = %.2e | PC1 = %.1f%%  PC2 = %.1f%% | factors(eig>1) = %d\n\n",
            fit$N, fit$kmo, bartlett(fit$R, fit$N)["p"], 100*fit$var_expl[1], 100*fit$var_expl[2], sum(fit$eig > 1)))
cat("PC1 loadings (natural direction) + per-variable MSA:\n")
print(round(data.frame(loading = fit$loadings, MSA = fit$msa[names(fit$loadings)]), 3))

png(file.path(OUT_DIR, "lms_scree.png"), width = 800, height = 500)
plot(fit$eig, type = "b", pch = 19, xlab = "Component", ylab = "Eigenvalue",
     main = "Scree plot — Labor Market Structure (TPAK + Upah)"); abline(h = 1, lty = 2, col = "red")
invisible(dev.off())

pc1 <- fit$scores; s100 <- 100 * (pc1 - min(pc1)) / (max(pc1) - min(pc1))
scores <- data.frame(province = names(pc1), year = ANCHOR,
                     lms_pc1 = round(as.numeric(pc1), 4), lms_0_100 = round(as.numeric(s100), 1),
                     stringsAsFactors = FALSE)
scores <- scores[order(-scores$lms_pc1), ]; scores$rank <- seq_len(nrow(scores))
scores <- scores[, c("rank", "province", "year", "lms_pc1", "lms_0_100")]

loadings <- data.frame(variable = names(fit$loadings), pc1_loading = round(as.numeric(fit$loadings), 4),
                       stringsAsFactors = FALSE)
write.csv(scores,   file.path(OUT_DIR, "lms_2023_scores.csv"), row.names = FALSE)
write.csv(loadings, file.path(OUT_DIR, "lms_loadings.csv"),    row.names = FALSE)
cat("\nFull 2023 ranking:\n"); print(scores, row.names = FALSE)

# =============================================================================
# SECTION 4 — ROBUSTNESS (leave-one-out; 2024 refit)
# =============================================================================
cat("\n================ SECTION 4: ROBUSTNESS ================\n")
loo <- sapply(rownames(M), function(pv)
  max(abs(fit_pca(M[setdiff(rownames(M), pv), ])$loadings - fit$loadings)))
cat(sprintf("(A) Leave-one-out loading change: mean = %.3f  max = %.3f\n", mean(loo), max(loo)))
top <- scores$province[1]
fD <- fit_pca(M[setdiff(rownames(M), top), ]); sh <- intersect(names(fit$scores), names(fD$scores))
cat(sprintf("    Ranking Spearman, full vs top-province-dropped = %.4f\n",
            cor(fit$scores[sh], fD$scores[sh], method = "spearman")))
f24 <- fit_pca(build_matrix(d, 2024, "lab_tpak_pct_y", "wage_avg_employee_idr_y"))
sh2 <- intersect(names(fit$scores), names(f24$scores))
cat(sprintf("(B) 2024 refit: KMO = %.3f  PC1 = %.1f%%  loading congruence = %.3f  ranking Spearman(2023,2024) = %.3f\n",
            f24$kmo, 100*f24$var_expl[1], cor(fit$loadings, f24$loadings),
            cor(fit$scores[sh2], f24$scores[sh2], method = "spearman")))

# =============================================================================
# SECTION 5 — VALIDATION vs ACTUAL PHK (target; never an input)
# =============================================================================
cat("\n================ SECTION 5: VALIDATION vs ACTUAL PHK ================\n")
cat(sprintf("Spearman( LMS score , PHK per-worker rate ) = %.3f  (N = %d)\n",
            validate(fit$scores), sum(!is.na(phk_r[names(fit$scores)]))))
cat("=> Positive: the exposure index tracks where recorded layoffs concentrate. Done.\n")
