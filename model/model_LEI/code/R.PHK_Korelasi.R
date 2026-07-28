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
macro_vars <- c("Brent", "PMI", "BI_Rate", "Volatilitas_Kurs", "IHPB", "Penjualan_Mobil", "Ekspor")
ccf_results <- do.call(rbind, lapply(macro_vars, function(v) get_pooled_ccf_sig(df_growth, v, "g_PHK")))

# 6. VISUALISASI: HEATMAP LEADING INDICATORS
ggplot(ccf_results, aes(x = Lag, y = Variable, fill = Correlation)) +
  geom_tile() +
  scale_fill_gradient2(low = "#1B5E20", mid = "white", high = "tomato", midpoint = 0) +
  theme_minimal() +
  labs(title = "Pooled Cross-Correlation: Makro ke PHK (Monthly Evaluated)",
       subtitle = "Lag 0-12 Bulan (Merah/Hijau = Arah Korelasi)",
       x = "Lag (Bulan)", y = "Indikator Makro")

# 7. TABEL RINGKASAN: OPTIMAL LEAD TIME ----
summary_table <- ccf_results %>%
  group_by(Variable) %>%
  filter(abs(Correlation) == max(abs(Correlation))) %>%
  rename(Optimal_Lag = Lag, Max_Corr = Correlation)

print(as.data.frame(summary_table))

# Export ke Excel
write.xlsx(ccf_results, "Evaluasi_CCF_Signifikansi_PHK.xlsx",
           sheetName = "CCF Bulanan",
           keepNA = TRUE,
           asTable = TRUE,
           tableStyle = "TableStyleMedium2")

