# =============================================================================
# LPI — Component 2: Labor Market Signals (Sinyal Pasar Kerja)
#   SCOPE (2023): CURRENT-SLACK signals only (Family B).
# =============================================================================
# Layoff Pressure Index (LPI), Indonesia PHK Early-Warning Dashboard.
#
# WHAT THIS COMPONENT IS
#   A "how slack / weak is the labor market RIGHT NOW?" signal, built from
#   current-level labor-market slack indicators: unemployment, under-employment,
#   part-time work, and Kemnaker registry flows (jobseekers, vacancies,
#   placements). Higher score = more slack = more layoff pressure.
#
# SCOPE DECISION (2026-07-15)
#   The originally-considered MOMENTUM variables (year-on-year growth / change)
#   are DEFERRED, not used here. Reasons: (1) conceptually momentum is a "change"
#   not a "state", and it does not belong in Component 1's structural exposure
#   (adding it collapses that PCA from 74% -> 51%); (2) in a single 2023 cross-
#   section momentum is very noisy and volatile (2023->2024 rank corr ~0.08).
#   With only 2023 data available, Component 2 = current-slack (Family B) only.
#   Momentum can graduate into its own signal later, once multiple years exist.
#
# METHOD — TRANSPARENT COMPOSITE, not PCA
#   A PCA on the 6 slack signals still does not cohere (PC1 ~36%, contradictory
#   loadings: open unemployment moves opposite to disguised under-utilisation).
#   So: orient each signal to +pressure -> z-score -> EQUAL-WEIGHT AVERAGE.
#   No shared-factor assumption; every signal an independent, equal vote.
#
# GRAIN / ANCHOR
#   province-year, anchor = 2023 (collapse master with month == 1). N = 34
#   (the 4 new Papua DOB provinces lack the slack sub-indicators). Recompute each
#   year (z-scored within the year); do NOT anchor-and-apply-forward.
#
# INPUT : data/clean/phk_master.csv
# OUTPUT: model/model_LPI/LPI2_Labor_Market_Signal/outputs/signal_component2_2023_scores.csv
#         model/model_LPI/LPI2_Labor_Market_Signal/outputs/signal_component2_variables.csv
#
# Run:  Rscript model/model_LPI/LPI2_Labor_Market_Signal/01_lpi_component2_signal.R
# =============================================================================

MASTER  <- "~/phk_dashboard/data/clean/phk_master.csv"
OUT_DIR <- "~/phk_dashboard/model/model_LPI/LPI2_Labor_Market_Signal/outputs"
ANCHOR  <- 2023
MIN_SIGNALS <- 4    # keep a province only if >= 4 of 6 slack signals are present
if (!dir.exists(OUT_DIR)) dir.create(OUT_DIR, recursive = TRUE)

# -----------------------------------------------------------------------------
# 1. Signal metadata: the 6 current-slack (Family B) variables.
#    pressure_dir "+": higher = MORE pressure ; "-": higher = LESS (sign-flipped).
#    facet: sub-grouping used only for interpretation/diagnostics.
# -----------------------------------------------------------------------------
SIGNALS <- rbind(
  data.frame(name="lvl_tpt",        facet="open_unemployment", pressure_dir="+", source="lab_tpt_pct_y"),
  data.frame(name="lvl_jobseekers", facet="open_unemployment", pressure_dir="+", source="1000 * lab_job_seekers_y / lab_working_pop_y"),
  data.frame(name="lvl_underemp",   facet="underutilisation",  pressure_dir="+", source="lab_underemp_share_pct_y"),
  data.frame(name="lvl_parttime",   facet="underutilisation",  pressure_dir="+", source="lab_part_time_share_pct_y"),
  data.frame(name="lvl_vacancies",  facet="labor_demand",      pressure_dir="-", source="1000 * lab_vacancies_registered_y / lab_working_pop_y"),
  data.frame(name="lvl_placements", facet="labor_demand",      pressure_dir="-", source="1000 * lab_placements_registered_y / lab_working_pop_y")
)

# -----------------------------------------------------------------------------
# 2. Build the oriented slack matrix (already flipped so higher = more pressure).
# -----------------------------------------------------------------------------
build_signals <- function(dat, yr) {
  y <- dat[dat$month == 1 & dat$year == yr, ]
  y$jobseekers_rate <- 1000 * y$lab_job_seekers_y          / y$lab_working_pop_y
  y$vacancies_rate  <- 1000 * y$lab_vacancies_registered_y / y$lab_working_pop_y
  y$placements_rate <- 1000 * y$lab_placements_registered_y/ y$lab_working_pop_y
  M <- data.frame(
    lvl_tpt         =  y$lab_tpt_pct_y,
    lvl_jobseekers  =  y$jobseekers_rate,
    lvl_underemp    =  y$lab_underemp_share_pct_y,
    lvl_parttime    =  y$lab_part_time_share_pct_y,
    lvl_vacancies   = -y$vacancies_rate,
    lvl_placements  = -y$placements_rate
  )
  rownames(M) <- y$province_name_std
  M[, SIGNALS$name]
}

# -----------------------------------------------------------------------------
# 3. Composite scorer: coverage filter -> z-score -> equal-weight average.
#    Also returns the 3 facet sub-scores for interpretation.
# -----------------------------------------------------------------------------
facet_avg <- function(Z, facet) rowMeans(Z[, SIGNALS$name[SIGNALS$facet == facet], drop = FALSE], na.rm = TRUE)
score_composite <- function(M) {
  M <- M[rowSums(!is.na(M)) >= MIN_SIGNALS, ]
  Z <- scale(M)
  list(slack = rowMeans(Z, na.rm = TRUE),
       open  = facet_avg(Z, "open_unemployment"),
       under = facet_avg(Z, "underutilisation"),
       demand= facet_avg(Z, "labor_demand"),
       Z = Z)
}

d <- read.csv(MASTER, stringsAsFactors = FALSE)
M <- build_signals(d, ANCHOR)

# =============================================================================
# STAGE A — DIAGNOSTIC: confirm PCA still does not cohere (justifies composite)
# =============================================================================
Mc <- M[complete.cases(M), ]
pca <- prcomp(Mc, center = TRUE, scale. = TRUE); ve <- pca$sdev^2 / sum(pca$sdev^2)
cc <- cor(Mc)
cat("================ STAGE A: PCA diagnostic (why NOT PCA) ================\n")
cat(sprintf("N=%d | PC1=%.1f%% PC2=%.1f%% | eigenvalues>1: %d | mean|corr|=%.2f\n",
            nrow(Mc), 100*ve[1], 100*ve[2], sum(pca$sdev^2 > 1), mean(abs(cc[upper.tri(cc)]))))
cat("   PC1 loadings:\n"); print(round(pca$rotation[,1], 2))
cat("=> Weak/contradictory (open vs disguised unemployment oppose) -> use composite.\n\n")

# =============================================================================
# STAGE B — HEADLINE: transparent equal-weight slack composite
# =============================================================================
sc <- score_composite(M)
slack <- sc$slack
s100  <- 100 * (slack - min(slack)) / (max(slack) - min(slack))

scores <- data.frame(province = names(slack), year = ANCHOR,
                     slack_z = round(slack, 4), slack_0_100 = round(s100, 1),
                     f_open_unemp_z = round(sc$open, 4), f_underutil_z = round(sc$under, 4),
                     f_labor_demand_z = round(sc$demand, 4), stringsAsFactors = FALSE)
scores <- scores[order(-scores$slack_z), ]; scores$rank <- seq_len(nrow(scores))
scores <- scores[, c("rank","province","year","slack_z","slack_0_100",
                     "f_open_unemp_z","f_underutil_z","f_labor_demand_z")]

write.csv(scores,  file.path(OUT_DIR, "signal_component2_2023_scores.csv"), row.names = FALSE)
write.csv(SIGNALS, file.path(OUT_DIR, "signal_component2_variables.csv"),   row.names = FALSE)

cat(sprintf("================ STAGE B: slack composite (N=%d, equal-weight z-avg) ================\n", nrow(scores)))
print(scores, row.names = FALSE)

# =============================================================================
# 4. ROBUSTNESS
# =============================================================================
cat("\n================ ROBUSTNESS ================\n")
Zk <- sc$Z
loso <- sapply(colnames(Zk), function(v)
  cor(slack, rowMeans(Zk[, setdiff(colnames(Zk), v)], na.rm = TRUE), method = "spearman"))
cat(sprintf("(A) Leave-one-signal-out rank stability: mean Spearman=%.3f, min=%.3f (drop '%s')\n",
            mean(loso), min(loso), names(which.min(loso))))
cat("(B) Facet correlations (open vs under vs demand):\n")
print(round(cor(data.frame(open=sc$open, under=sc$under, demand=sc$demand)), 2))
sc24 <- score_composite(build_signals(d, 2024)); sh <- intersect(names(slack), names(sc24$slack))
cat(sprintf("(C) 2024 recompute: ranking Spearman 2023 vs 2024 = %.3f (shared %d provinces)\n",
            cor(slack[sh], sc24$slack[sh], method = "spearman"), length(sh)))
cat("\nDone.\n")
