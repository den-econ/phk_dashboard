#!/usr/bin/env Rscript
# ============================================================================
# 00_fit_pillars.R  —  Reproducible re-fit of the two Stage-1 vulnerability
#                      pillars (L9 labour market, E5 economic structure).
# ----------------------------------------------------------------------------
# WHAT THIS DOES
#   Re-fits both pillars from ../../data/clean/phk_master.csv for EVERY year
#   present in the data, using the proven PCA recipe (PC1 of standardised
#   province-year variables, oriented so the anchor variable loads positive,
#   min-max rescaled to 0-100). It reproduces the frozen fitted object
#   outputs/models.rds field-for-field (n, excl, kmo, msa, eig, pc1, cond,
#   load, s100, score, phk_rate, st, sr, pt, pr, cor) and writes the result to
#   outputs/models_refit.rds. It does NOT overwrite outputs/models.rds.
#
#   A verification block then compares the re-fit against the frozen object for
#   both pillars and all overlapping years, writing outputs/_refit_verification.txt.
#
# METHOD (per pillar, per year)
#   1. subset phk_master to the year; collapse to one row per province via mean
#      (na.rm=TRUE) — the pillar inputs are annual (_y) and constant within a
#      province-year.
#   2. select the pillar's variable columns; complete.cases() listwise-drops
#      any province missing an input (reproduces the exact N and excl set).
#   3. Z <- scale(X); R <- cor(Z); E <- eigen(R).
#   4. loadings v <- E$vectors[,1] (named by var); flip sign so v[anchor] >= 0.
#   5. score sc <- Z %*% v (named by province); s100 <- 100*(sc-min)/(max-min).
#
# DIAGNOSTICS (implemented in base R — no psych/openxlsx available)
#   kmo / msa : overall & per-variable Kaiser-Meyer-Olkin from R and its
#               inverse (anti-image / partial-correlation formula).
#   cond      : condition number = max(eigenvalue)/min(eigenvalue) of R.
#   phk_rate  : phk_y / lab_formal_workers_y (per province, used provinces only).
#   sr / st   : Spearman corr of score vs phk_rate / vs total PHK (phk_y).
#   pr / pt   : Pearson equivalents. (score and s100 give identical corrs.)
#               Correlations use pairwise-complete obs (provinces with missing
#               PHK are dropped from that correlation only).
#
# Inputs : ../../data/clean/phk_master.csv ; outputs/models.rds (metadata +
#          verification reference only — NOT used to compute the re-fit numbers)
# Outputs: outputs/models_refit.rds ; outputs/_refit_verification.txt
# Run from: model/model_LPI/   ->   Rscript code/00_fit_pillars.R
# ============================================================================

MASTER  <- "../../data/clean/phk_master.csv"
FROZEN  <- "outputs/models_frozen_2025.rds"   # immutable validated baseline (verification reference)
OUT_RDS <- "outputs/models_refit.rds"
OUT_TXT <- "outputs/_refit_verification.txt"

stopifnot(file.exists(MASTER), file.exists(FROZEN))

d <- read.csv(MASTER, stringsAsFactors = FALSE, check.names = FALSE)
Mfrozen <- readRDS(FROZEN)

## ---- pillar specifications -------------------------------------------------
## name/desc/dom/lab/anchor mirror the frozen object exactly. `map` gives, for
## each pillar variable, either a source column name or a function of the row.
pillars <- list(
  L9 = list(
    name = "Labour Model 9",
    desc = "Formal · manufacturing · agri · full-time · underemployment · average wage",
    dom  = "labour",
    vars = c("formal", "manuf", "agri", "fulltime", "underemp", "avgwage"),
    lab  = c(formal = "Formal labour share", manuf = "Manuf labour share",
             agri = "Agri labour share",
             fulltime = "Full-time share", underemp = "Underemployment",
             avgwage = "Average wage"),
    anchor = "formal",
    map = list(
      formal   = function(df) df$lab_formal_share_pct_y,
      manuf    = function(df) df$emp_share_manuf_pct_y,
      agri     = function(df) df$emp_share_agri_pct_y,
      fulltime = function(df) df$lab_full_time_share_pct_y,
      underemp = function(df) df$lab_underemp_share_pct_y,
      avgwage  = function(df) df$wage_avg_employee_idr_y
    )
  ),
  E5 = list(
    name = "Economic Structure (4-var, clean)",
    desc = "Government · export · manuf · agri (÷ PDRB) — import dropped (collinear w/ export), references & inert vars removed",
    dom  = "econ",
    vars = c("govt", "exp_rat", "manuf", "agri"),
    lab  = c(govt = "Government/PDRB", exp_rat = "Export/PDRB",
             manuf = "Manuf %PDRB", agri = "Agri %PDRB"),
    anchor = "manuf",
    map = list(
      govt    = function(df) df$macro_pdrb_gov_cons_share_pct_y,
      exp_rat = function(df) df$trade_export_share_pdrb_pct_y,   # BPS export, IDR-milyar share of PDRB
      manuf   = function(df) df$macro_pdrb_manuf_share_pct_y,
      agri    = function(df) df$macro_pdrb_agri_share_pct_y
    )
  )
)

## ---- KMO (overall + per-variable MSA) from a correlation matrix ------------
kmo_from_cor <- function(R) {
  Ri <- solve(R)
  Q  <- diag(1 / sqrt(diag(Ri)))
  P  <- -(Q %*% Ri %*% Q)          # anti-image / partial-correlation matrix
  r2 <- R; diag(r2) <- 0           # zero the diagonals before summing
  p2 <- P; diag(p2) <- 0
  overall <- sum(r2^2) / (sum(r2^2) + sum(p2^2))
  msa <- sapply(seq_len(ncol(R)), function(j)
    sum(r2[j, ]^2) / (sum(r2[j, ]^2) + sum(p2[j, ]^2)))
  names(msa) <- colnames(R)
  list(kmo = overall, msa = msa)
}

## ---- build the analysis matrix for one pillar-year -------------------------
## Returns one row per province with the pillar's derived variables + the two
## PHK columns needed for validation correlations.
build_year <- function(spec, df_year) {
  X <- as.data.frame(lapply(spec$map, function(f) f(df_year)))
  names(X) <- spec$vars
  X$phk_y  <- df_year$phk_y
  X$fw_y   <- df_year$lab_formal_workers_y
  X$prov   <- df_year$province_name_std
  # collapse to one row per province (mean, na.rm) — inputs are annual/constant
  agg <- aggregate(X[, c(spec$vars, "phk_y", "fw_y"), drop = FALSE],
                   by = list(prov = X$prov),
                   FUN = function(z) mean(z, na.rm = TRUE))
  rownames(agg) <- agg$prov
  agg
}

## ---- fit one pillar for one year -------------------------------------------
fit_pillar_year <- function(spec, agg) {
  vars   <- spec$vars
  anchor <- spec$anchor
  Xall   <- agg[, vars, drop = FALSE]
  cc     <- complete.cases(Xall)
  excl   <- agg$prov[!cc]

  X <- Xall[cc, , drop = FALSE]
  Z <- scale(X)                          # standardise (n-1 SD)
  R <- cor(Z)
  E <- eigen(R)

  v <- E$vectors[, 1]; names(v) <- vars
  if (v[anchor] < 0) v <- -v

  sc <- as.numeric(Z %*% v); names(sc) <- rownames(X)
  s100 <- 100 * (sc - min(sc)) / (max(sc) - min(sc))

  km <- kmo_from_cor(R)

  # PHK validation vectors, aligned to the provinces actually used
  used     <- rownames(X)
  phk_rate <- agg[used, "phk_y"] / agg[used, "fw_y"]; names(phk_rate) <- used
  phk_tot  <- agg[used, "phk_y"];                     names(phk_tot)  <- used

  sr <- suppressWarnings(cor(sc, phk_rate, method = "spearman", use = "pairwise.complete.obs"))
  st <- suppressWarnings(cor(sc, phk_tot,  method = "spearman", use = "pairwise.complete.obs"))
  pr <- suppressWarnings(cor(sc, phk_rate, method = "pearson",  use = "pairwise.complete.obs"))
  pt <- suppressWarnings(cor(sc, phk_tot,  method = "pearson",  use = "pairwise.complete.obs"))

  list(
    n     = as.integer(sum(cc)),
    excl  = as.character(excl),
    kmo   = km$kmo,
    msa   = km$msa,
    eig   = E$values,
    pc1   = E$values[1] / sum(E$values),
    cond  = max(E$values) / min(E$values),
    load  = v,
    s100  = s100,
    score = sc,
    phk_rate = phk_rate,
    st = st, sr = sr, pt = pt, pr = pr,
    # frozen object stores the correlation matrix rounded to 3 dp (all PCA
    # computation above used full-precision R); round here to match exactly.
    cor = round(R, 3)
  )
}

## ---- fit all years for one pillar ------------------------------------------
fit_pillar <- function(spec, d) {
  years <- sort(unique(d$year))
  E <- list()
  for (yr in years) {
    agg <- build_year(spec, d[d$year == yr, , drop = FALSE])
    ncc <- sum(complete.cases(agg[, spec$vars, drop = FALSE]))
    if (ncc < length(spec$vars) + 1) {
      message(sprintf("  [%s %d] skipped: only %d complete-case province(s) (need >= %d)",
                      spec$name, yr, ncc, length(spec$vars) + 1))
      next
    }
    E[[as.character(yr)]] <- fit_pillar_year(spec, agg)
  }
  # top-level $cor: correlation matrix of the latest fitted year, labelled
  latest <- names(E)[length(E)]
  topcor <- E[[latest]]$cor
  dimnames(topcor) <- list(spec$lab[spec$vars], spec$lab[spec$vars])

  list(name = spec$name, desc = spec$desc, dom = spec$dom,
       vars = spec$vars, lab = spec$lab, anchor = spec$anchor,
       E = E, cor = topcor)
}

## ---- run -------------------------------------------------------------------
message("Fitting pillars from ", MASTER)
M <- list()
for (k in names(pillars)) {
  message("Pillar ", k, " (", pillars[[k]]$name, ")")
  M[[k]] <- fit_pillar(pillars[[k]], d)
}
saveRDS(M, OUT_RDS)
message("Wrote ", OUT_RDS)

# ============================================================================
# VERIFICATION  — refit vs frozen, both pillars, all overlapping years
# ============================================================================
con <- file(OUT_TXT, open = "wt")
w <- function(...) { cat(..., "\n", file = con, sep = ""); cat(..., "\n", sep = "") }

w("Re-fit verification  —  ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
w("phk_master: ", normalizePath(MASTER))
w("frozen    : ", normalizePath(FROZEN))
w("refit     : ", OUT_RDS)
w("")
w("Notes on diagnostic formulas that were matched to the frozen object:")
w("  cond     = max(eigenvalue)/min(eigenvalue) of the correlation matrix")
w("  kmo/msa  = anti-image (partial-correlation) Kaiser-Meyer-Olkin, base-R")
w("  phk_rate = phk_y / lab_formal_workers_y  (used provinces only)")
w("  sr/st    = Spearman(score, phk_rate) / Spearman(score, phk_y)")
w("  pr/pt    = Pearson equivalents  (score and s100 give identical values)")
w(strrep("=", 78))

pass_all <- TRUE
fnum <- function(x) if (is.null(x) || length(x) == 0 || is.na(x)) "   NA  " else sprintf("%7.4f", x)

for (k in names(M)) {
  Mf <- Mfrozen[[k]]; Mr <- M[[k]]
  yrs <- intersect(names(Mf$E), names(Mr$E))
  w("")
  w("PILLAR ", k, "  (", Mr$name, ")")
  for (yr in yrs) {
    ef <- Mf$E[[yr]]; er <- Mr$E[[yr]]

    cp   <- intersect(names(ef$s100), names(er$s100))
    ds   <- if (length(cp)) max(abs(er$s100[cp]  - ef$s100[cp]))  else NA
    dl   <- max(abs(as.numeric(er$load) - as.numeric(ef$load)))
    dsc  <- if (length(cp)) max(abs(er$score[cp] - ef$score[cp])) else NA
    dpr  <- {
      cpp <- intersect(names(ef$phk_rate), names(er$phk_rate))
      max(abs(er$phk_rate[cpp] - ef$phk_rate[cpp]), na.rm = TRUE)
    }
    dcor <- max(abs(unname(er$cor) - unname(ef$cor)))
    n_ok    <- er$n == ef$n
    excl_ok <- setequal(er$excl, ef$excl)

    core_ok <- isTRUE(ds < 1e-6) && isTRUE(dl < 1e-6) && isTRUE(dsc < 1e-6) &&
               isTRUE(dcor < 1e-9) && n_ok && excl_ok
    diag_ok <- abs(er$kmo - ef$kmo) < 5e-3 &&
               abs(er$cond - ef$cond) < 1e-2 * max(1, abs(ef$cond)) &&
               abs(er$sr - ef$sr) < 5e-3 && abs(er$st - ef$st) < 5e-3
    ok <- core_ok && diag_ok
    pass_all <- pass_all && ok

    w("")
    w("  year ", yr, "   ", if (ok) "PASS" else "FAIL")
    w(sprintf("    n: frozen=%d refit=%d  %s", ef$n, er$n, if (n_ok) "ok" else "MISMATCH"))
    w(sprintf("    excl: frozen={%s} refit={%s}  %s",
              paste(sort(ef$excl), collapse = ","),
              paste(sort(er$excl), collapse = ","),
              if (excl_ok) "ok" else "MISMATCH"))
    w(sprintf("    max|s100 diff| = %.3e", ds))
    w(sprintf("    max|load diff| = %.3e", dl))
    w(sprintf("    max|score diff|= %.3e", dsc))
    w(sprintf("    max|cor diff|  = %.3e", dcor))
    w(sprintf("    max|phk_rate diff| = %.3e", dpr))
    w(sprintf("    %-5s  frozen   refit", ""))
    w(sprintf("    kmo   %s  %s", fnum(ef$kmo),  fnum(er$kmo)))
    w(sprintf("    cond  %s  %s", fnum(ef$cond), fnum(er$cond)))
    w(sprintf("    sr    %s  %s", fnum(ef$sr),   fnum(er$sr)))
    w(sprintf("    st    %s  %s", fnum(ef$st),   fnum(er$st)))
    w(sprintf("    pr    %s  %s", fnum(ef$pr),   fnum(er$pr)))
    w(sprintf("    pt    %s  %s", fnum(ef$pt),   fnum(er$pt)))
  }
}

w("")
w(strrep("=", 78))
w("OVERALL: ", if (pass_all) "PASS — re-fit reproduces the frozen pillars." else
                             "FAIL — see mismatches above.")
close(con)
message("Wrote ", OUT_TXT)
if (!pass_all) quit(status = 1)
