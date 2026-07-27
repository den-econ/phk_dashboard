#!/usr/bin/env Rscript
# ============================================================================
# 01_pillar_pca.R  —  Stage-1 vulnerability pillars (documentation + score export)
# ----------------------------------------------------------------------------
# Two first-layer PCA indices, each PC1 of standardised province-year variables:
#   * L9  Indeks Kerentanan Pasar Kerja   (labour-market vulnerability)
#   * E5  Indeks Kerentanan Struktural Ekonomi (economic-structure vulnerability)
#
# IMPORTANT — provenance:
#   The fitted pillar objects live in outputs/models.rds and are the *validated
#   authoritative artifact* behind the published LPI report. The original
#   interactive fitting script was not preserved, so this file does NOT re-fit
#   from raw; it documents the specification and re-exports the validated pillar
#   scores/spec so the pipeline is self-describing. Ultimate source of the
#   variables is data/clean/phk_master.csv (province-year).
#   Actual PHK is used only to validate these indices, never as an input.
#
# Method (both pillars): standardise the listed variables within each year ->
#   PCA -> PC1 = the pillar score, oriented so the anchor variable loads positive
#   -> min-max rescaled to 0-100 within year for display. Diagnostics (KMO, MSA,
#   condition number, Spearman vs PHK) are in outputs/pillar_metrics.csv (from 05).
#
# Inputs : outputs/models.rds ; data/clean/phk_master.csv (lineage check only)
# Outputs: outputs/pillar_variable_spec.csv
#          outputs/pillar_scores_pasar_kerja.csv
#          outputs/pillar_scores_struktural.csv
# Run from: model/model_LPI/
# ============================================================================
MASTER <- "../../data/clean/phk_master.csv"
if (!file.exists(MASTER)) warning("phk_master.csv not found at ", MASTER,
  " — lineage note only; pillar scores come from outputs/models.rds")
M  <- readRDS("outputs/models.rds")
M$L9$name <- "Indeks Kerentanan Pasar Kerja"          # match published report/dashboard
M$E5$name <- "Indeks Kerentanan Struktural Ekonomi"
ys <- as.character(2022:2025)

## ---- variable specification (authoritative from the fitted objects) -------
spec <- do.call(rbind, lapply(c("L9","E5"), function(k){ m<-M[[k]]
  data.frame(index=m$name, var=m$vars, label=as.character(m$lab[m$vars]),
             anchor=(m$vars==m$anchor), row.names=NULL)}))
write.csv(spec, "outputs/pillar_variable_spec.csv", row.names=FALSE)
cat("Pillar specifications\n"); print(spec, row.names=FALSE)

## ---- export per-pillar province-year scores (0-100) -----------------------
export_scores <- function(key, file){ m<-M[[key]]
  rows <- lapply(ys, function(yr){ s<-m$E[[yr]]$s100
    data.frame(year=as.integer(yr), province=names(s),
               score_0_100=round(as.numeric(s),1), row.names=NULL)})
  df <- do.call(rbind, rows); df <- df[order(df$year, -df$score_0_100), ]
  write.csv(df, file, row.names=FALSE); nrow(df)}

n1 <- export_scores("L9","outputs/pillar_scores_pasar_kerja.csv")
n2 <- export_scores("E5","outputs/pillar_scores_struktural.csv")
cat(sprintf("\nexported pillar scores: Pasar Kerja %d rows, Struktural %d rows\n", n1, n2))
