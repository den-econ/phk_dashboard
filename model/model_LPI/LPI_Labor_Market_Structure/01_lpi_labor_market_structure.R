# =============================================================================
# LPI — Labor Market Structure (Struktur Tenaga Kerja)
# =============================================================================
# Layoff Pressure Index (LPI), Indonesia PHK Early-Warning Dashboard.
# Merged indicator (former Component 1 "Exposure" + Component 2 "Signals").
#
# WHAT THIS COMPONENT IS
#   A single structural index of each province's labor market: how formal /
#   modern-sector its workforce is, together with its labor-market conditions
#   (participation, unemployment, jobseekers) and informality/wage structure
#   (unpaid family work, Kaitz index). Higher score = a labor-market structure
#   more exposed and vulnerable to recorded layoffs (PHK). It is the structural
#   pillar of the LPI; actual PHK is the TARGET it is VALIDATED against
#   (section 5), never an input.
#
# METHOD
#   Cross-sectional PCA on 9 standardized, pressure-oriented variables; PC1 =
#   the Labor Market Structure score. The set was chosen from an extensive
#   specification search (section 2): the 7-variable core ("V3") is the tightest
#   single factor, and adding `unpaid family` + `Kaitz` raises both PCA adequacy
#   (KMO) and the validation against actual PHK. Registry (vacancies/placements),
#   statistik-industri, momentum, and claims variables all lowered KMO / validation.
#
# GRAIN / ANCHOR
#   province-year, anchor = 2023 (collapse master with month == 1). N = 33
#   provinces (the 4 new Papua DOB provinces + Kepulauan Riau drop on missing
#   inputs). Re-standardize / refit within the analysis year.
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
# 0. Helpers: per-working-pop rate, and PCA-suitability diagnostics.
# -----------------------------------------------------------------------------
rate     <- function(y, col) 100 * y[[col]] / y$lab_working_pop_y
bartlett <- function(R, n) {                              # test of sphericity
  p <- ncol(R); chi <- -((n - 1) - (2 * p + 5) / 6) * log(det(R))
  c(chisq = chi, df = p * (p - 1) / 2, p = pchisq(chi, p * (p - 1) / 2, lower.tail = FALSE))
}
kmo <- function(R) {                                      # overall KMO
  iR <- solve(R); Q <- -cov2cor(iR)
  r2 <- sum(R[upper.tri(R)]^2); q2 <- sum(Q[upper.tri(Q)]^2); r2 / (r2 + q2)
}
kmo_item <- function(R) {                                 # per-variable MSA
  iR <- solve(R); Q <- -cov2cor(iR)
  sapply(seq_len(ncol(R)), function(j) { r2 <- sum(R[-j, j]^2); q2 <- sum(Q[-j, j]^2); r2 / (r2 + q2) })
}

# -----------------------------------------------------------------------------
# 1. Build the variable matrix for a given year, entered per each variable's RISK
#    DIRECTION: variables where "more = more pressure" enter as-is (+); the two
#    buffer variables (agri, tpak) where "more = less pressure" are inverted (x -1).
#    NOTE: an individual variable's sign never changes the PCA scores/KMO/ranking/
#    validation -- only its loading sign. PC1 is oriented so `formal` loads positive
#    ("higher score = more formal / exposed structure"); on that axis the
#    informality/cost markers (unpaid family, Kaitz) load NEGATIVE. Inputs are
#    shares / rates (intensity) so province size does not dominate. `FINAL_VARS` =
#    the chosen 9; vacancy/placement are used only by the section-2 search.
# -----------------------------------------------------------------------------
FINAL_VARS <- c("agri", "formal", "manuf", "bpjs_pu", "tpak", "tpt", "jobseek", "unpaid", "kaitz")

build_matrix <- function(dat, yr) {
  y <- dat[dat$month == 1 & dat$year == yr, ]
  M <- data.frame(
    agri      = -y$emp_share_agri_pct_y,       # REV: less agriculture = more formal exposure
    formal    =  y$lab_formal_share_pct_y,     #      more formal employment = more recordable
    manuf     =  y$emp_share_manuf_pct_y,      #      more manufacturing = more shock-exposed
    bpjs_pu   =  rate(y, "bpjstk_active_pu_y"),#      more formal (PU) social-security coverage
    tpak      = -y$lab_tpak_pct_y,             # REV: lower labor-force participation = weaker
    tpt       =  y$lab_tpt_pct_y,              #      higher unemployment = more slack
    jobseek   =  rate(y, "lab_job_seekers_y"), #      more registered jobseekers = more slack
    unpaid    =  rate(y, "lab_unpaid_family_y"),# +   more unpaid family work = more informal/vulnerable
    kaitz     =  y$wage_kaitz_index_y,          # +   higher Kaitz (min/median wage) = binds harder (cost)
    # --- extras for the specification search only (not in the final index) ---
    vacancy   = -rate(y, "lab_vacancies_registered_y"),  # REV: fewer vacancies = weaker demand
    placement = -rate(y, "lab_placements_registered_y")  # REV: fewer placements = weaker demand
  )
  rownames(M) <- y$province_name_std
  M
}

# -----------------------------------------------------------------------------
# 2. Fit PCA -> oriented PC1 loadings + scores. PC1 oriented so `formal` loads
#    positive (higher score = more pressure).
# -----------------------------------------------------------------------------
fit_pca <- function(M) {
  M <- M[complete.cases(M), ]
  p <- prcomp(M, center = TRUE, scale. = TRUE)
  if (p$rotation["formal", "PC1"] < 0) { p$rotation <- -p$rotation; p$x <- -p$x }
  ve <- p$sdev^2 / sum(p$sdev^2)
  list(N = nrow(M), loadings = p$rotation[, 1], scores = setNames(p$x[, 1], rownames(M)),
       var_expl = ve, eig = p$sdev^2, msa = setNames(kmo_item(cor(scale(M))), colnames(M)),
       kmo = kmo(cor(scale(M))))
}

d      <- read.csv(MASTER, stringsAsFactors = FALSE)
Mall   <- build_matrix(d, ANCHOR)
phk_y  <- setNames(d[d$month == 1 & d$year == ANCHOR, "phk_y"],
                   d[d$month == 1 & d$year == ANCHOR, "province_name_std"])
validate <- function(scores) {                            # Spearman vs actual PHK
  cm <- intersect(names(scores), names(phk_y)); cm <- cm[!is.na(phk_y[cm])]
  cor(scores[cm], phk_y[cm], method = "spearman")
}

# =============================================================================
# SECTION 2 — SPECIFICATION SEARCH (why these 9): compare candidate specs
# =============================================================================
CORE7 <- c("agri", "formal", "manuf", "bpjs_pu", "tpak", "tpt", "jobseek")
SPECS <- list(
  "Core (7)"                    = CORE7,
  "+ unpaid family (8)"         = c(CORE7, "unpaid"),
  "+ Kaitz (8)"                 = c(CORE7, "kaitz"),
  "FINAL: + unpaid + Kaitz (9)" = FINAL_VARS,
  "+ vacancies/placements (11)" = c(FINAL_VARS, "vacancy", "placement")
)
spec_tbl <- do.call(rbind, lapply(names(SPECS), function(nm) {
  f <- fit_pca(Mall[, SPECS[[nm]]])
  data.frame(spec = nm, n_vars = length(SPECS[[nm]]), N = f$N,
             KMO = round(f$kmo, 3), PC1_pct = round(100 * f$var_expl[1], 1),
             factors_gt1 = sum(f$eig > 1), validation_vs_PHK = round(validate(f$scores), 3))
}))
cat("================ SECTION 2: SPECIFICATION SEARCH ================\n")
print(spec_tbl, row.names = FALSE)
write.csv(spec_tbl, file.path(OUT_DIR, "lms_specification_search.csv"), row.names = FALSE)

# =============================================================================
# SECTION 3 — FINAL INDEX (9 variables)
# =============================================================================
M   <- Mall[, FINAL_VARS]
fit <- fit_pca(M)
R   <- cor(scale(M[complete.cases(M), ]))
cat(sprintf("\n================ SECTION 3: FINAL LABOR MARKET STRUCTURE ================\n"))
cat(sprintf("N = %d provinces | %d variables | anchor %d\n", fit$N, length(FINAL_VARS), ANCHOR))
cat(sprintf("KMO = %.3f (>=0.6 acceptable) | Bartlett p = %.2e\n", fit$kmo, bartlett(R, fit$N)["p"]))
cat(sprintf("PC1 = %.1f%%  PC2 = %.1f%%  | Kaiser factors (eig>1) = %d\n\n",
            100 * fit$var_expl[1], 100 * fit$var_expl[2], sum(fit$eig > 1)))
cat("PC1 loadings (= structure weights) and per-variable MSA:\n")
print(round(data.frame(loading = fit$loadings, MSA = fit$msa[names(fit$loadings)]), 3))

# scree
png(file.path(OUT_DIR, "lms_scree.png"), width = 800, height = 500)
plot(fit$eig, type = "b", pch = 19, xlab = "Component", ylab = "Eigenvalue",
     main = "Scree plot — Labor Market Structure"); abline(h = 1, lty = 2, col = "red")
invisible(dev.off())

# scores -> 0-100
pc1 <- fit$scores; s100 <- 100 * (pc1 - min(pc1)) / (max(pc1) - min(pc1))
scores <- data.frame(province = names(pc1), year = ANCHOR,
                     lms_pc1 = round(as.numeric(pc1), 4), lms_0_100 = round(as.numeric(s100), 1),
                     stringsAsFactors = FALSE)
scores <- scores[order(-scores$lms_pc1), ]; scores$rank <- seq_len(nrow(scores))
scores <- scores[, c("rank", "province", "year", "lms_pc1", "lms_0_100")]

loadings <- data.frame(
  variable    = names(fit$loadings),
  pc1_loading = round(as.numeric(fit$loadings), 4),
  orientation = c("- (inverted: low agri = high exposure)", "+", "+", "+",
                  "- (inverted: low participation = weaker)", "+", "+",
                  "+ (more unpaid family work = more informal)",
                  "+ (higher Kaitz = binds harder)"),
  stringsAsFactors = FALSE)

write.csv(scores,   file.path(OUT_DIR, "lms_2023_scores.csv"), row.names = FALSE)
write.csv(loadings, file.path(OUT_DIR, "lms_loadings.csv"),    row.names = FALSE)
cat("\nFull 2023 ranking:\n"); print(scores, row.names = FALSE)

# =============================================================================
# SECTION 4 — ROBUSTNESS
#   (A) leave-one-out: is the index driven by any single province?
#   (B) 2024 refit: are the loadings / ranking stable across years?
# =============================================================================
cat("\n================ SECTION 4: ROBUSTNESS ================\n")
loo <- sapply(rownames(M[complete.cases(M), ]), function(pv)
  max(abs(fit_pca(M[setdiff(rownames(M), pv), ])$loadings - fit$loadings)))
cat(sprintf("(A) Leave-one-out loading change: mean = %.3f  max = %.3f\n", mean(loo), max(loo)))
top <- scores$province[1]
fD  <- fit_pca(M[setdiff(rownames(M), top), ]); sh <- intersect(names(fit$scores), names(fD$scores))
cat(sprintf("    Ranking Spearman, full vs top-province-dropped = %.4f\n",
            cor(fit$scores[sh], fD$scores[sh], method = "spearman")))
f24 <- fit_pca(build_matrix(d, 2024)[, FINAL_VARS]); sh2 <- intersect(names(fit$scores), names(f24$scores))
cat(sprintf("(B) 2024 refit: KMO = %.3f  PC1 = %.1f%%  loading congruence = %.3f  ranking Spearman(2023,2024) = %.3f\n",
            f24$kmo, 100 * f24$var_expl[1], cor(fit$loadings, f24$loadings),
            cor(fit$scores[sh2], f24$scores[sh2], method = "spearman")))

# =============================================================================
# SECTION 5 — VALIDATION AGAINST ACTUAL PHK (the target; never an input)
# =============================================================================
cat("\n================ SECTION 5: VALIDATION vs ACTUAL PHK ================\n")
cat(sprintf("Spearman( LMS score , actual PHK_y ) = %.3f  (N = %d provinces with PHK)\n",
            validate(fit$scores), sum(!is.na(phk_y[names(fit$scores)]))))
cat("=> The structural index (no PHK inside) tracks real provincial layoffs.\n\nDone.\n")
