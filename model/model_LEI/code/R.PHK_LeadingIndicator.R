# ==============================================================================
# PROVINCIAL & NATIONAL LABOUR LEADING ECONOMIC INDICATOR (LEI / LLI)
# Target Variable: Continuous Accumulation Index (Base: Januari 2023 = 100)
# Included Predictors: PMI, BI_Rate, Volatilitas_Kurs, Brent, IHPB, Ekspor, Penjualan_Mobil
# ==============================================================================

# ------------------------------
# 0) Libraries
# ------------------------------
library(readxl)
library(dplyr)
library(tidyr)
library(zoo)
library(lubridate)
library(ggplot2)
library(openxlsx)

# ------------------------------
# 1) Load Data & Align Columns
# ------------------------------
df_tahun <- read_excel("data_layoff.xlsx", sheet = "Tahunan")
df_bulan <- read_excel("data_layoff.xlsx", sheet = "Bulanan")

colnames(df_tahun) <- c(
  "Provinsi", "Tahun", "PHK_T", "Jml_Bekerja", "UMP", "Growth_UMP", 
  "Upah_Buruh", "Jml_TK_Industri", "PDRB_Riil", "FDI", "IHP", "IHK", 
  "Ekspor", "Impor", "NPL", "BI_Rate", "Kurs", "IKK"
)
base_pekerja <- df_tahun %>% select(Provinsi, Tahun, Jml_Bekerja)

# Penyesuaian nama kolom Sheet 'Bulanan'
colnames(df_bulan) <- c(
  "Provinsi", "Tahun", "Bulan", "PHK", "PMI", "IHK", 
  "Ekspor", "Impor", "NPL", "BI_Rate", "Kurs", "Brent", "IHPB", "Kurs_Vol", "Sales_Mobil"
)

# Penggabungan & Forward-Fill Jumlah Pekerja
df_gabungan <- df_bulan %>%
  left_join(base_pekerja, by = c("Provinsi", "Tahun")) %>%
  arrange(Provinsi, Tahun, Bulan) %>%
  group_by(Provinsi) %>%
  tidyr::fill(Jml_Bekerja, .direction = "down") %>%
  ungroup() %>%
  mutate(
    across(c(PHK, PMI, IHK, Ekspor, Impor, BI_Rate, Brent, IHPB, Kurs_Vol, Sales_Mobil), ~ as.numeric(as.character(.))),
    date = as.Date(paste(Tahun, Bulan, "01", sep = "-"))
  )

base_date <- as.Date("2023-01-01")

# Bulan terakhir yang diekspor/diplot. Ganti SATU baris ini setiap update bulanan.
END_DATE <- as.Date("2026-08-01")

# ------------------------------
# 2) TCB & Standardization Helpers
# ------------------------------
fill_missing_locf <- function(x) {
  if (all(is.na(x))) return(x)
  na.locf(na.locf(x, na.rm = FALSE), fromLast = TRUE)
}

# Symmetric growth rate (untuk data tipe rasio/flow)
sym_g <- function(x) {
  denom <- x + dplyr::lag(x)
  ifelse(denom == 0 | is.na(denom), 0, 200 * (x - dplyr::lag(x)) / denom)
}

# First difference (untuk data tipe level/persentase suku bunga)
diff_g <- function(x) {
  res <- x - dplyr::lag(x)
  ifelse(is.na(res), 0, res)
}

# Agregasi Komposit weighted by std deviation (Metode The Conference Board)
composite_from_changes <- function(df_change_mat) {
  sds <- apply(df_change_mat, 2, sd, na.rm = TRUE)
  sds <- ifelse(sds == 0 | is.na(sds), 0.001, sds)
  
  # Bobot invers std deviasi agar variabel volatil tidak mendominasi
  w <- (1 / sds) / sum(1 / sds, na.rm = TRUE)
  
  mat <- as.matrix(df_change_mat)
  mat[is.na(mat)] <- 0
  
  as.numeric(mat %*% w)
}

accumulate_index_based <- function(g, dates, base_target_date) {
  g[is.na(g)] <- 0
  raw_idx <- cumprod(1 + (g / 100))
  
  pos_base <- which(dates == base_target_date)
  if (length(pos_base) == 0) {
    base_val <- raw_idx[1]
  } else {
    base_val <- raw_idx[pos_base[1]]
  }
  
  final_idx <- (raw_idx / base_val) * 100
  as.numeric(final_idx)
}

# ------------------------------
# 3) Process Loop Per Provinsi
# ------------------------------
daftar_provinsi <- unique(df_gabungan$Provinsi)
tabel_lei_provinsi <- data.frame()

for (prov in daftar_provinsi) {
  
  sub_prov <- df_gabungan %>% 
    filter(Provinsi == prov) %>%
    arrange(date) %>%
    mutate(across(c(PHK, PMI, BI_Rate, Kurs_Vol, Brent, IHPB, Ekspor, Sales_Mobil), fill_missing_locf))
  
  if (nrow(sub_prov) > 12) { # Membutuhkan > 12 observasi karena transformasi YoY
    
    # --- A. Hitung Target Continuous Accumulation Index (Indeks PHK) ---
    sub_prov <- sub_prov %>%
      mutate(
        PHK_prev = dplyr::lag(PHK),
        PHK_murni = ifelse(Bulan == 1 | is.na(PHK_prev), PHK, PHK - PHK_prev),
        PHK_murni = ifelse(PHK_murni < 0, 0, PHK_murni),
        PHK_continuous_accum = cumsum(PHK_murni),
        target_accum_rate = ifelse(is.na(Jml_Bekerja) | Jml_Bekerja == 0, 0, PHK_continuous_accum / Jml_Bekerja)
      )
    
    base_row <- sub_prov %>% filter(date == base_date)
    val_base_target <- if(nrow(base_row) > 0 && !is.na(base_row$target_accum_rate[1]) && base_row$target_accum_rate[1] > 0) {
      base_row$target_accum_rate[1]
    } else {
      pos_val <- sub_prov$target_accum_rate[sub_prov$target_accum_rate > 0]
      if(length(pos_val) > 0) pos_val[1] else 0.00001
    }
    
    target_idx <- (sub_prov$target_accum_rate / val_base_target) * 100
    
    # --- B. Transformasi Spesifik 7 Indikator Makro Terpilih ---
    sub_prov_transformed <- sub_prov %>%
      mutate(
        # 1. Level & Index Series
        c_PMI              = diff_g(PMI),
        c_BI_Rate          = diff_g(BI_Rate),
        c_Volatilitas_Kurs = diff_g(Kurs_Vol),
        c_IHPB             = diff_g((IHPB / first(IHPB)) * 100),
        
        # 2. Growth & Log-Diff Series
        c_Brent            = sym_g(c(rep(NA, 12), diff(log(Brent), lag = 12))),
        c_Ekspor           = sym_g(c(NA, diff(log(ifelse(Ekspor <= 0, 1, Ekspor))))),
        c_Penjualan_Mobil  = sym_g(c(rep(NA, 12), diff(log(ifelse(Sales_Mobil <= 0, 1, Sales_Mobil)), lag = 12)))
      )
    
    # --- C. Standardisasi Arah Dampak ke Risiko PHK (Inversion) ---
    # Pro-siklikal (PMI, Ekspor, Sales Mobil): Kenaikan -> PHK Turun (Invert sign: x -1)
    # Counter-siklikal (BI Rate, Volatilitas Kurs, Brent, IHPB): Kenaikan -> PHK Naik (Keep sign)
    
    mat_prediktor <- sub_prov_transformed %>% 
      mutate(
        c_PMI             = -1 * c_PMI,
        c_Ekspor          = -1 * c_Ekspor,
        c_Penjualan_Mobil = -1 * c_Penjualan_Mobil
      ) %>%
      select(c_PMI, c_BI_Rate, c_Volatilitas_Kurs, c_Brent, c_IHPB, c_Ekspor, c_Penjualan_Mobil)
    
    # Matriks perubahan komposit
    lei_change_raw <- composite_from_changes(mat_prediktor)
    
    # Akumulasi ke bentuk Indeks (Jan 2023 = 100)
    lei_idx <- accumulate_index_based(lei_change_raw, sub_prov_transformed$date, base_date)
    
    hasil_prov <- data.frame(
      date                 = sub_prov$date,
      Tahun                = sub_prov$Tahun,
      Bulan                = sub_prov$Bulan,
      Provinsi             = prov,
      Jumlah_Bekerja       = sub_prov$Jml_Bekerja,
      Indeks_Target_PHK    = round(target_idx, 2),
      Indeks_LEI_Labour    = round(lei_idx, 2)
    )
    
    tabel_lei_provinsi <- rbind(tabel_lei_provinsi, hasil_prov)
  }
}

# ------------------------------
# 4) Agregasi ke Level Nasional & Perhitungan MA 6-Bulan
# ------------------------------
tabel_lei_nasional <- tabel_lei_provinsi %>%
  group_by(date, Tahun, Bulan) %>%
  summarise(
    Total_Bekerja_Nasional = sum(Jumlah_Bekerja, na.rm = TRUE),
    Indeks_Target_PHK      = round(sum(Indeks_Target_PHK * Jumlah_Bekerja, na.rm = TRUE) / sum(Jumlah_Bekerja, na.rm = TRUE), 2),
    Indeks_LEI_Labour      = round(sum(Indeks_LEI_Labour * Jumlah_Bekerja, na.rm = TRUE) / sum(Jumlah_Bekerja, na.rm = TRUE), 2),
    .groups = 'drop'
  ) %>%
  arrange(date) %>%
  mutate(
    Provinsi = "NASIONAL",
    
    # Perubahan bulanan (Month-on-Month Change) dari Indeks Target PHK
    delta_indeks_phk = Indeks_Target_PHK - dplyr::lag(Indeks_Target_PHK, default = first(Indeks_Target_PHK)),
    delta_indeks_phk = ifelse(delta_indeks_phk < 0, 0, delta_indeks_phk),
    
    # 6-Month Moving Average dari Δ Indeks PHK
    phk_ma6 = round(zoo::rollmean(delta_indeks_phk, k = 6, fill = NA, align = "right"), 2)
  )

# ------------------------------
# 5) Plot s.d. END_DATE
# ------------------------------
plot_data_nasional <- tabel_lei_nasional %>%
  filter(date >= as.Date("2023-01-01") & date <= END_DATE)

max_lei     <- max(plot_data_nasional$Indeks_LEI_Labour, na.rm = TRUE)
max_target  <- max(plot_data_nasional$Indeks_Target_PHK, na.rm = TRUE)

base_lei    <- 100
base_target <- 100

scaling_factor <- ifelse((max_target - base_target) == 0, 1, (max_lei - base_lei) / (max_target - base_target))

ggplot(plot_data_nasional, aes(x = date)) +
  geom_line(aes(y = Indeks_LEI_Labour, color = "Indeks LLI (Prediktor Komposit)"), size = 1.2, linetype = "solid") +
  geom_line(aes(y = base_lei + (Indeks_Target_PHK - base_target) * scaling_factor, 
                color = "Target Indikator (Indeks PHK)"), size = 1.2, linetype = "solid") +
  geom_hline(yintercept = 100, linetype = "dotted", color = "gray40", alpha = 0.7, size = 0.8) +
  scale_y_continuous(
    name = "Indeks LLI (Januari 2023=100)",
    sec.axis = sec_axis(~ base_target + (. - base_lei) / scaling_factor, 
                        name = "Indeks PHK (Januari 2023=100)",
                        labels = scales::comma)
  ) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") + 
  scale_color_manual(values = c(
    "Target Indikator (Indeks PHK)" = "orange",        
    "Indeks LLI (Prediktor Komposit)" = "brown"
  )) +
  labs(
    title = "Labour Leading Indicator (LLI) vs Indeks PHK",
    subtitle = "Komponen LLI: PMI, BI Rate, Volatilitas Kurs, Brent, IHPB, Ekspor, Penjualan Mobil",
    x = "Tahun", 
    color = "Komponen Indikator"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 16, margin = margin(b = 6)),
    plot.subtitle = element_text(size = 11, color = "gray30", margin = margin(b = 15)),
    legend.position = "bottom",
    legend.title = element_blank(),
    panel.grid.minor = element_blank(),
    axis.title.y.left = element_text(color = "brown", face = "bold", size = 10),
    axis.title.y.right = element_text(color = "orange", face = "bold", size = 10),
    axis.text.y.left = element_text(color = "brown", size = 9),
    axis.text.y.right = element_text(color = "orange", size = 9),
    axis.text.x = element_text(angle = 0, hjust = 0.5) 
  )

# ------------------------------
# 6) Plot MA 6-Bulan PHK  s.d. END_DATE
# ------------------------------
plot_data_ma6 <- tabel_lei_nasional %>%
  filter(date >= as.Date("2023-01-01") & date <= END_DATE)

max_lei_ma    <- max(plot_data_ma6$Indeks_LEI_Labour, na.rm = TRUE)
min_lei_ma    <- min(plot_data_ma6$Indeks_LEI_Labour, na.rm = TRUE)

max_target_ma <- max(plot_data_ma6$phk_ma6, na.rm = TRUE)
min_target_ma <- min(plot_data_ma6$phk_ma6, na.rm = TRUE)

scaling_factor_ma <- (max_lei_ma - min_lei_ma) / ifelse((max_target_ma - min_target_ma) == 0, 1, (max_target_ma - min_target_ma))

ggplot(plot_data_ma6, aes(x = date)) +
  geom_line(aes(y = Indeks_LEI_Labour, color = "Indeks LLI (Prediktor Komposit)"), size = 1.2, linetype = "solid") +
  geom_line(aes(y = min_lei_ma + (phk_ma6 - min_target_ma) * scaling_factor_ma, 
                color = "Target PHK (6-Month MA Δ Indeks)"), size = 1.2, linetype = "solid") +
  geom_hline(yintercept = 100, linetype = "dotted", color = "gray40", alpha = 0.7, size = 0.8) +
  scale_y_continuous(
    name = "Indeks LLI (Januari 2023=100)",
    sec.axis = sec_axis(~ min_target_ma + (. - min_lei_ma) / scaling_factor_ma, 
                        name = "MA 6 Bulan Δ Indeks PHK",
                        labels = scales::comma_format(accuracy = 0.1))
  ) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") + 
  scale_color_manual(values = c(
    "Target PHK (6-Month MA Δ Indeks)" = "orange",        
    "Indeks LLI (Prediktor Komposit)" = "brown"
  )) +
  labs(
    title = "Labour Leading Indicator (LLI) vs Indeks PHK",
    subtitle = "Komponen LLI: PMI, BI Rate, Volatilitas Kurs, Brent, IHPB, Ekspor, Penjualan Mobil",
    x = "Tahun", 
    color = "Komponen Indikator"
  ) +
  theme_minimal(base_size = 14) +
  theme(
    plot.title = element_text(face = "bold", size = 16, margin = margin(b = 6)),
    plot.subtitle = element_text(size = 11, color = "gray30", margin = margin(b = 15)),
    legend.position = "bottom",
    legend.title = element_blank(),
    panel.grid.minor = element_blank(),
    axis.title.y.left = element_text(color = "brown", face = "bold", size = 10),
    axis.title.y.right = element_text(color = "orange", face = "bold", size = 10),
    axis.text.y.left = element_text(color = "brown", size = 9),
    axis.text.y.right = element_text(color = "orange", size = 9),
    axis.text.x = element_text(angle = 0, hjust = 0.5) 
  )

# ------------------------------
# 7) EKSPOR HASIL KE EXCEL (Dipangkas s.d. END_DATE)
# ------------------------------
export_nasional <- tabel_lei_nasional %>%
  filter(date <= END_DATE) %>%
  select(date, Tahun, Bulan, Total_Bekerja_Nasional, Indeks_Target_PHK, delta_indeks_phk, phk_ma6, Indeks_LEI_Labour, Provinsi)

export_provinsi <- tabel_lei_provinsi %>%
  filter(date <= END_DATE)

wb <- createWorkbook()
addWorksheet(wb, "LEI Nasional")
addWorksheet(wb, "LEI Per Provinsi")

writeDataTable(wb, "LEI Nasional", export_nasional, tableStyle = "TableStyleMedium4")
writeDataTable(wb, "LEI Per Provinsi", export_provinsi, tableStyle = "TableStyleMedium2")

setColWidths(wb, "LEI Nasional", cols = 1:ncol(export_nasional), widths = "auto")
setColWidths(wb, "LEI Per Provinsi", cols = 1:ncol(export_provinsi), widths = "auto")

saveWorkbook(wb, "Komposit_LEI_Ketenagakerjaan.xlsx", overwrite = TRUE)

# ------------------------------
# 8) CHECK FOR CORRELATION & OPTIMAL LEAD-LAG (0 - 12 BULAN)
# ------------------------------

# 1. Set max Lag (Rentang Jan 2023 s.d. END_DATE)
max_lag <- 12

df_corr_analysis <- tabel_lei_nasional %>%
  filter(date >= as.Date("2023-01-01") & date <= END_DATE) %>%
  select(date, Indeks_LEI_Labour, Indeks_Target_PHK, phk_ma6)

corr_results <- data.frame(
  Lag_Bulan = 0:max_lag,
  Korelasi_LLI_vs_Indeks_PHK_Level = NA_real_,
  Korelasi_LLI_vs_MA6_Delta_PHK   = NA_real_
)

# 2. Korelasi Pearson LLI(t) dengan Target(t + k)
# k = jumlah bulan LLI leading indikator PHK
for (k in 0:max_lag) {
  target_phk_lead <- dplyr::lead(df_corr_analysis$Indeks_Target_PHK, k)
  ma6_phk_lead    <- dplyr::lead(df_corr_analysis$phk_ma6, k)
  
  corr_results$Korelasi_LLI_vs_Indeks_PHK_Level[k + 1] <- cor(
    df_corr_analysis$Indeks_LEI_Labour, 
    target_phk_lead, 
    use = "complete.obs"
  )
  
  corr_results$Korelasi_LLI_vs_MA6_Delta_PHK[k + 1] <- cor(
    df_corr_analysis$Indeks_LEI_Labour, 
    ma6_phk_lead, 
    use = "complete.obs"
  )
}

# Hasil Korelasi
corr_results <- corr_results %>%
  mutate(
    Korelasi_LLI_vs_Indeks_PHK_Level = round(Korelasi_LLI_vs_Indeks_PHK_Level, 4),
    Korelasi_LLI_vs_MA6_Delta_PHK    = round(Korelasi_LLI_vs_MA6_Delta_PHK, 4)
  )

# 3. Identifikasi Peak Lag (Korelasi Maksimum)
opt_lag_level  <- corr_results$Lag_Bulan[which.max(corr_results$Korelasi_LLI_vs_Indeks_PHK_Level)]
max_corr_level <- max(corr_results$Korelasi_LLI_vs_Indeks_PHK_Level, na.rm = TRUE)

opt_lag_ma6    <- corr_results$Lag_Bulan[which.max(corr_results$Korelasi_LLI_vs_MA6_Delta_PHK)]
max_corr_ma6    <- max(corr_results$Korelasi_LLI_vs_MA6_Delta_PHK, na.rm = TRUE)

# 4. Print Summary
cat("\n======================================================================\n")
cat("  RINGKASAN ANALISIS CROSS CORRELATION (LEAD-LAG LLI VS INDIKATOR PHK)\n")
cat("======================================================================\n")
cat(sprintf("1. LLI vs Indeks Target PHK (Level):\n"))
cat(sprintf("   - Korelasi Max : %.4f\n", max_corr_level))
cat(sprintf("   - Optimal Lag           : LLI lead %d Bulan di depan\n\n", opt_lag_level))

cat(sprintf("2. LLI vs MA-6 Bulan Δ Indeks PHK:\n"))
cat(sprintf("   - Korelasi Max : %.4f\n", max_corr_ma6))
cat(sprintf("   - Optimal Lag           : LLI lead %d Bulan di depan\n", opt_lag_ma6))
cat("======================================================================\n\n")

print(corr_results)
