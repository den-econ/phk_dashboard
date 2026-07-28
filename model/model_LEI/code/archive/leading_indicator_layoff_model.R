# ==============================================================================
# ANALISIS CCF BULANAN: IDENTIFIKASI LEADING INDICATORS PHK
# ==============================================================================

# 1. LOAD LIBRARIES ----
library(readxl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(zoo)
library(openxlsx) 

# 2. LOAD & CLEAN DATA (Sheet: Bulanan)
df_bulan <- read_excel("data_layoff.xlsx", sheet = "Bulanan")
df_bulan <- as.data.frame(df_bulan)

colnames(df_bulan) <- c(
  "Provinsi", "Tahun", "Bulan", "PHK", "PMI", "IHK",
  "Ekspor", "Impor", "NPL", "BI_Rate", "Kurs", "Brent", "IHPB", "Kurs_Vol", "Sales_Mobil"
)

# Konversi ke Date dan pastikan numerik
df_bulan <- df_bulan %>%
  mutate(Date = as.Date(paste(Tahun, Bulan, "01", sep = "-"))) %>%
  mutate(across(PHK:Sales_Mobil, as.numeric)) %>%
  # Proteksi nilai PHK 0 sebelum log
  mutate(PHK_adj = ifelse(PHK <= 0 | is.na(PHK), 1, PHK)) %>%
  arrange(Provinsi, Date)

# 3. TRANSFORMASI VARIABEL (Growth Rate / Log-Diff)
df_growth <- df_bulan %>%
  group_by(Provinsi) %>%
  mutate(
    g_PHK            = PHK_adj,
    PMI              = PMI,
    BI_Rate          = BI_Rate,                   # BI Rate digunakan LANGSUNG (level) tanpa growth
    Volatilitas_Kurs = Kurs_Vol,                  # Volatilitas Kurs digunakan LANGSUNG (level) tanpa growth
    
    Brent            = c(rep(NA, 12), diff(log(Brent), lag = 12)),
    IHPB             = (IHPB / first(IHPB)) * 100,
    
    Ekspor           = c(NA, diff(log(ifelse(Ekspor <= 0, 1, Ekspor)))),
    Penjualan_Mobil  = c(rep(NA, 12), diff(log(ifelse(Sales_Mobil <= 0, 1, Sales_Mobil)), lag = 12))) %>%
  
  ungroup() %>%
  drop_na(g_PHK) # Membuang baris NA pertama hasil differencing

# 4. FUNGSI POOLED CROSS-CORRELATION ----
# Kita akan menguji lag dari -12 hingga 0 (Leading 12 bulan ke belakang)
get_pooled_ccf_sig <- function(data, x_var, y_var, max_lag = 12) {
  results <- data.frame(Lag = 0:max_lag, Correlation = NA, P_Value = NA, Significant = NA)
  
  for(l in 0:max_lag) {
    shifted_data <- data %>%
      group_by(Provinsi) %>%
      mutate(shifted_x = lag(!!sym(x_var), l)) %>%
      ungroup() %>%
      filter(!is.na(shifted_x))
    
    # Menghapus argumen 'use = "complete.obs"' yang memicu eror kritis pada cor.test
    ct <- cor.test(shifted_data$shifted_x, shifted_data[[y_var]])
    
    results$Correlation[l+1] <- ct$estimate
    results$P_Value[l+1]     <- ct$p.value
    results$Significant[l+1] <- ifelse(ct$p.value < 0.05, "Yes*", "No")
    
    
  }
  results$Variable <- x_var
  return(results)
}

# 5. RUN MODEL SEMUA VARIABEL MAKRO
macro_vars <- c("PMI", "BI_Rate", "Volatilitas_Kurs", "Brent", "IHPB", "Penjualan_Mobil")
ccf_results <- do.call(rbind, lapply(macro_vars, function(v) get_pooled_ccf_sig(df_growth, v, "g_PHK")))

# 6. VISUALISASI: HEATMAP LEADING INDICATORS
ggplot(ccf_results, aes(x = Lag, y = Variable, fill = Correlation)) +
  geom_tile() +
  scale_fill_gradient2(low = "#1B5E20", mid = "white", high = "tomato", midpoint = 0) +
  theme_minimal() +
  labs(title = "Pooled Cross-Correlation: Makro ke PHK (Monthly Evaluated)",
       subtitle = "Lag 0-12 Bulan (Merah/Hijau = Arah Korelasi)",
       x = "Lag (Bulan)", y = "Indikator Makro")

# 7a. TABEL RINGKASAN: OPTIMAL LEAD TIME ----
summary_table <- ccf_results %>%
  group_by(Variable) %>%
  filter(abs(Correlation) == max(abs(Correlation))) %>%
  rename(Optimal_Lag = Lag, Max_Corr = Correlation)

print(as.data.frame(summary_table))

# 7b. TABEL KORELASI PADA LAG TARGET (1, 3, 6, dan 12 Bulan)
target_lags <- c(1, 3, 6, 12)
target_table <- ccf_results %>%
  filter(Lag %in% target_lags) %>%
  mutate(
    # Format agar mudah dibaca: Nilai Korelasi (p-value) & tanda bintang jika signifikan
    Est_With_Sig = paste0(
      round(Correlation, 3),
      ifelse(Significant == "Yes*", "*", ""),
      " (p=", format.pval(P_Value, digits = 3), ")"
    )
  ) %>%
  select(Variable, Lag, Est_With_Sig) %>%
  pivot_wider(names_from = Lag, values_from = Est_With_Sig, names_prefix = "Lag_")

print(as.data.frame(target_table))

# Export ke Excel
write.xlsx(ccf_results, "Evaluasi_CCF_Signifikansi_PHK.xlsx",
           sheetName = "CCF Bulanan",
           keepNA = TRUE,
           asTable = TRUE,
           tableStyle = "TableStyleMedium2")



# ==============================================================================
# PROVINCIAL & NATIONAL LABOUR LEADING ECONOMIC INDICATOR (LEI)
# Target Variable: Continuous Accumulation Index (Base: Januari 2023 = 100)
# Included Predictors: PMI, IHK, Ekspor, Impor, Sales_Mobil
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
# 1) Load Data & Align Column
# ------------------------------
df_tahun <- read_excel("data_layoff.xlsx", sheet = "Tahunan")
df_bulan <- read_excel("data_layoff.xlsx", sheet = "Bulanan")

colnames(df_tahun) <- c(
  "Provinsi", "Tahun", "PHK_T", "Jml_Bekerja", "UMP", "Growth_UMP", 
  "Upah_Buruh", "Jml_TK_Industri", "PDRB_Riil", "FDI", "IHP", "IHK", 
  "Ekspor", "Impor", "NPL", "BI_Rate", "Kurs", "IKK"
)
base_pekerja <- df_tahun %>% select(Provinsi, Tahun, Jml_Bekerja)

# Penyesuaian nama kolom lembar Bulanan (menambahkan Sales_Mobil)
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
    across(c(PHK, PMI, IHK, Ekspor, Impor, Sales_Mobil), ~ as.numeric(as.character(.))),
    date = as.Date(paste(Tahun, Bulan, "01", sep = "-"))
  )

# Periode basis indeks baru (Januari 2023 = 100)
base_date <- as.Date("2023-01-01")

# ------------------------------
# 2) TCB Helpers
# ------------------------------
fill_missing_locf <- function(x) {
  if (all(is.na(x))) return(x)
  na.locf(na.locf(x, na.rm = FALSE), fromLast = TRUE)
}

sym_g <- function(x) {
  denom <- x + dplyr::lag(x)
  ifelse(denom == 0 | is.na(denom), 0, 200 * (x - dplyr::lag(x)) / denom)
}

composite_from_growths <- function(df_growth_mat) {
  sds <- apply(df_growth_mat, 2, sd, na.rm = TRUE)
  sds <- ifelse(sds == 0 | is.na(sds), 0.001, sds)
  w <- (1 / sds) / sum(1 / sds, na.rm = TRUE)
  
  mat <- as.matrix(df_growth_mat)
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
# 3) Loop Run LEI & Target Continuous Index Per Provinsi
# ------------------------------
daftar_provinsi <- unique(df_gabungan$Provinsi)
tabel_lei_provinsi <- data.frame()

for (prov in daftar_provinsi) {
  
  sub_prov <- df_gabungan %>% 
    filter(Provinsi == prov) %>%
    arrange(date) %>%
    mutate(across(c(PHK, PMI, IHK, Ekspor, Impor, Sales_Mobil), fill_missing_locf))
  
  if (nrow(sub_prov) > 2) {
    
    # 1. Hitung PHK Bulanan Murni -> PHK Continuous Accumulation
    sub_prov <- sub_prov %>%
      mutate(
        PHK_prev = dplyr::lag(PHK),
        PHK_murni = ifelse(Bulan == 1 | is.na(PHK_prev), PHK, PHK - PHK_prev),
        PHK_murni = ifelse(PHK_murni < 0, 0, PHK_murni),
        PHK_continuous_accum = cumsum(PHK_murni)
      ) %>%
      mutate(
        target_accum_rate = ifelse(is.na(Jml_Bekerja) | Jml_Bekerja == 0, 0, PHK_continuous_accum / Jml_Bekerja)
      )
    
    # 2. Transformasi langsung target rate ke bentuk Indeks (Jan 2023 = 100)
    base_row <- sub_prov %>% filter(date == base_date)
    val_base_target <- if(nrow(base_row) > 0 && !is.na(base_row$target_accum_rate[1]) && base_row$target_accum_rate[1] > 0) {
      base_row$target_accum_rate[1]
    } else {
      pos_val <- sub_prov$target_accum_rate[sub_prov$target_accum_rate > 0]
      if(length(pos_val) > 0) pos_val[1] else 0.00001
    }
    
    target_idx <- (sub_prov$target_accum_rate / val_base_target) * 100
    
    # 3. Hitung TCB Komposit LEI (Garis Brown) — Termasuk Penjualan Mobil
    sub_prov_g <- sub_prov %>%
      mutate(
        g_PMI    = sym_g(PMI),
        g_IHK    = sym_g(IHK),
        g_Ekspor = sym_g(Ekspor),
        g_Impor  = sym_g(Impor),
        g_Mobil  = sym_g(Sales_Mobil) # <--- Penjualan Mobil ditambahkan
      )
    
    mat_prediktor <- sub_prov_g %>% 
      select(g_PMI, g_IHK, g_Ekspor, g_Impor, g_Mobil) %>% 
      slice(-1)
    
    lei_growth_raw <- composite_from_growths(mat_prediktor)
    lei_growth      <- c(0, lei_growth_raw)
    lei_idx         <- accumulate_index_based(lei_growth, sub_prov_g$date, base_date)
    
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
# 4) Agregasi ke Level Nasional (Weighted Average)
# ------------------------------
tabel_lei_nasional <- tabel_lei_provinsi %>%
  group_by(date, Tahun, Bulan) %>%
  summarise(
    Total_Bekerja_Nasional = sum(Jumlah_Bekerja, na.rm = TRUE),
    Indeks_Target_PHK      = round(sum(Indeks_Target_PHK * Jumlah_Bekerja, na.rm = TRUE) / sum(Jumlah_Bekerja, na.rm = TRUE), 2),
    Indeks_LEI_Labour      = round(sum(Indeks_LEI_Labour * Jumlah_Bekerja, na.rm = TRUE) / sum(Jumlah_Bekerja, na.rm = TRUE), 2),
    .groups = 'drop'
  ) %>%
  mutate(Provinsi = "NASIONAL")

# ------------------------------
# 5) Ekspor Hasil ke Excel Multi-Sheet
# ------------------------------
wb <- createWorkbook()
addWorksheet(wb, "LEI Nasional")
addWorksheet(wb, "LEI Per Provinsi")

writeDataTable(wb, "LEI Nasional", tabel_lei_nasional, tableStyle = "TableStyleMedium4")
writeDataTable(wb, "LEI Per Provinsi", tabel_lei_provinsi, tableStyle = "TableStyleMedium2")

setColWidths(wb, "LEI Nasional", cols = 1:ncol(tabel_lei_nasional), widths = "auto")
setColWidths(wb, "LEI Per Provinsi", cols = 1:ncol(tabel_lei_provinsi), widths = "auto")

saveWorkbook(wb, "Komposit_LEI_Ketenagakerjaan.xlsx", overwrite = TRUE)

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

# Penyesuaian nama kolom lembar Bulanan
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

# ------------------------------
# 2) TCB & Standardization Helpers
# ------------------------------
fill_missing_locf <- function(x) {
  if (all(is.na(x))) return(x)
  na.locf(na.locf(x, na.rm = FALSE), fromLast = TRUE)
}

# Symmetric growth rate (untuk data bertipe rasio/flow)
sym_g <- function(x) {
  denom <- x + dplyr::lag(x)
  ifelse(denom == 0 | is.na(denom), 0, 200 * (x - dplyr::lag(x)) / denom)
}

# First difference (untuk data bertipe level/persentase suku bunga)
diff_g <- function(x) {
  res <- x - dplyr::lag(x)
  ifelse(is.na(res), 0, res)
}

# Agregasi Komposit Berbobot Invers Deviasi Standar (Metode The Conference Board)
composite_from_changes <- function(df_change_mat) {
  sds <- apply(df_change_mat, 2, sd, na.rm = TRUE)
  sds <- ifelse(sds == 0 | is.na(sds), 0.001, sds)
  
  # Bobot invers deviasi standar agar variabel volatil tidak mendominasi
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
# 3) Process Loop Per Provinsi dengan Transformasi Baru
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
# 4) Agregasi ke Level Nasional (Weighted Average)
# ------------------------------
tabel_lei_nasional <- tabel_lei_provinsi %>%
  group_by(date, Tahun, Bulan) %>%
  summarise(
    Total_Bekerja_Nasional = sum(Jumlah_Bekerja, na.rm = TRUE),
    Indeks_Target_PHK      = round(sum(Indeks_Target_PHK * Jumlah_Bekerja, na.rm = TRUE) / sum(Jumlah_Bekerja, na.rm = TRUE), 2),
    Indeks_LEI_Labour      = round(sum(Indeks_LEI_Labour * Jumlah_Bekerja, na.rm = TRUE) / sum(Jumlah_Bekerja, na.rm = TRUE), 2),
    .groups = 'drop'
  ) %>%
  mutate(Provinsi = "NASIONAL")

# ------------------------------
# 5) Ekspor Hasil ke Excel Multi-Sheet
# ------------------------------
wb <- createWorkbook()
addWorksheet(wb, "LEI Nasional")
addWorksheet(wb, "LEI Per Provinsi")

writeDataTable(wb, "LEI Nasional", tabel_lei_nasional, tableStyle = "TableStyleMedium4")
writeDataTable(wb, "LEI Per Provinsi", tabel_lei_provinsi, tableStyle = "TableStyleMedium2")

setColWidths(wb, "LEI Nasional", cols = 1:ncol(tabel_lei_nasional), widths = "auto")
setColWidths(wb, "LEI Per Provinsi", cols = 1:ncol(tabel_lei_provinsi), widths = "auto")

saveWorkbook(wb, "Komposit_LEI_Ketenagakerjaan.xlsx", overwrite = TRUE)

# ------------------------------
# 6) VISUALISASI: Dual Axis Plot Basis Indeks 100)
# ------------------------------
plot_data_nasional <- tabel_lei_nasional %>%
  filter(date >= as.Date("2023-01-01"))

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
    subtitle = "Komponen LLI: PMI, BI Rate, Volatilitas Kurs, Brent (YoY), IHPB, Ekspor, Penjualan Mobil (YoY)",
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
# 7) TRANSFORMASI MA-6 PHK & VISUALISASI ULANG (Dual Axis)
# ------------------------------

# 1. Transformasi Data: Δ Indeks Target PHK & 6-Month Moving Average
plot_data_ma6 <- tabel_lei_nasional %>%
  arrange(date) %>%
  mutate(
    # Perubahan bulanan (Month-on-Month Change) dari Indeks Target PHK
    delta_indeks_phk = Indeks_Target_PHK - dplyr::lag(Indeks_Target_PHK, default = first(Indeks_Target_PHK)),
    delta_indeks_phk = ifelse(delta_indeks_phk < 0, 0, delta_indeks_phk),
    
    # 6-Month Moving Average dari Δ Indeks PHK
    phk_ma6 = zoo::rollmean(delta_indeks_phk, k = 6, fill = NA, align = "right")
  ) %>%
  filter(date >= as.Date("2023-01-01")) # Filter periode tampilan dari Jan 2023

# 2. Perhitungan Faktor Skala untuk Dual Axis Plot
max_lei_ma    <- max(plot_data_ma6$Indeks_LEI_Labour, na.rm = TRUE)
min_lei_ma    <- min(plot_data_ma6$Indeks_LEI_Labour, na.rm = TRUE)

max_target_ma <- max(plot_data_ma6$phk_ma6, na.rm = TRUE)
min_target_ma <- min(plot_data_ma6$phk_ma6, na.rm = TRUE)

# Menghitung scaling factor & shift agar kedua seri terpetakan dengan proporsional
scaling_factor_ma <- (max_lei_ma - min_lei_ma) / ifelse((max_target_ma - min_target_ma) == 0, 1, (max_target_ma - min_target_ma))

# 3. Visualisasi Dual Axis Plot (LLI vs 6-Month MA Δ Indeks PHK)
ggplot(plot_data_ma6, aes(x = date)) +
  # Garis LLI Komposit (Sumbu Kiri - Cokelat)
  geom_line(aes(y = Indeks_LEI_Labour, color = "Indeks LLI (Prediktor Komposit)"), size = 1.2, linetype = "solid") +
  
  # Garis MA-6 Δ Indeks PHK (Sumbu Kanan - Oranye)
  geom_line(aes(y = min_lei_ma + (phk_ma6 - min_target_ma) * scaling_factor_ma, 
                color = "Target PHK (6-Month MA Δ Indeks)"), size = 1.2, linetype = "solid") +
  
  # Garis Referensi Baseline Indeks LLI (100)
  geom_hline(yintercept = 100, linetype = "dotted", color = "gray40", alpha = 0.7, size = 0.8) +
  
  # Pengaturan Dual Y-Axis
  scale_y_continuous(
    name = "Indeks LLI (Januari 2023=100)",
    sec.axis = sec_axis(~ min_target_ma + (. - min_lei_ma) / scaling_factor_ma, 
                        name = "MA 6 Bulan Δ Indeks PHK",
                        labels = scales::comma_format(accuracy = 0.1))
  ) +
  
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") + 
  
  # Skema Warna Konsisten (Brown vs Orange)
  scale_color_manual(values = c(
    "Target PHK (6-Month MA Δ Indeks)" = "orange",        
    "Indeks LLI (Prediktor Komposit)" = "brown"
  )) +
  
  labs(
    title = "Labour Leading Indicator (LLI) vs Indeks PHK",
    subtitle = "Komponen LLI: PMI, BI Rate, Volatilitas Kurs, Brent (YoY), IHPB, Ekspor, Penjualan Mobil (YoY)",
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
# 8) ANALISIS CROSS CORRELATION & OPTIMAL LAG (LEAD-LAG ANALYSIS)
# ------------------------------

# 1. Matriks Korelasi untuk Lag 0 hingga 12 Bulan
max_lag <- 12
df_corr_analysis <- plot_data_ma6 %>% select(date, Indeks_LEI_Labour, Indeks_Target_PHK, phk_ma6)

corr_results <- data.frame(
  Lag_Bulan = 0:max_lag,
  Korelasi_LLI_vs_Indeks_PHK = NA_real_,
  Korelasi_LLI_vs_MA6_PHK   = NA_real_
)

# 2. Perhitungan Korelasi Pearson LLI(t) dengan Target(t + k)
for (k in 0:max_lag) {
  # LLI memimpin (leads) Target sebesar k bulan
  target_phk_lead <- dplyr::lead(df_corr_analysis$Indeks_Target_PHK, k)
  ma6_phk_lead    <- dplyr::lead(df_corr_analysis$phk_ma6, k)
  
  corr_results$Korelasi_LLI_vs_Indeks_PHK[k + 1] <- cor(df_corr_analysis$Indeks_LEI_Labour, target_phk_lead, use = "complete.obs")
  corr_results$Korelasi_LLI_vs_MA6_PHK[k + 1]   <- cor(df_corr_analysis$Indeks_LEI_Labour, ma6_phk_lead, use = "complete.obs")
}

# 3. Identifikasi Optimal Lag (Korelasi Maksimum)
opt_lag_level <- corr_results$Lag_Bulan[which.max(corr_results$Korelasi_LLI_vs_Indeks_PHK)]
max_corr_level <- max(corr_results$Korelasi_LLI_vs_Indeks_PHK, na.rm = TRUE)

opt_lag_ma6   <- corr_results$Lag_Bulan[which.max(corr_results$Korelasi_LLI_vs_MA6_PHK)]
max_corr_ma6   <- max(corr_results$Korelasi_LLI_vs_MA6_PHK, na.rm = TRUE)

# 4. Print hasil
cat("\n========================================================\n")
cat("  RINGKASAN ANALISIS KORELASI SILANG (LEAD-LAG LLI)\n")
cat("========================================================\n")
cat(sprintf("1. LLI vs Indeks Target PHK (Level):\n"))
cat(sprintf("   - Korelasi Maksimum : %.4f\n", max_corr_level))
cat(sprintf("   - Optimal Lead Lag  : LLI memimpin %d bulan\n\n", opt_lag_level))

cat(sprintf("2. LLI vs MA-6 Δ Indeks PHK:\n"))
cat(sprintf("   - Korelasi Maksimum : %.4f\n", max_corr_ma6))
cat(sprintf("   - Optimal Lead Lag  : LLI memimpin %d bulan\n", opt_lag_ma6))
cat("========================================================\n\n")

# Display Tabel Korelasi
print(corr_results)
