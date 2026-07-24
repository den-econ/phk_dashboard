# ==============================================================================
# ANALISIS LAYOFF DATA PANEL INDONESIA (2022-2025)
# ==============================================================================

# 1. INSTALL DAN LOAD PACKAGES YANG DIBUTUHKAN
required_packages <- c("plm", "glmmTMB", "lmtest", "sandwich", "dplyr", "tidyr")
new_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if(length(new_packages)) install.packages(new_packages)

library(readxl)
library(plm)
library(glmmTMB)
library(lmtest)
library(sandwich)
library(dplyr)
library(tidyr)

# 2. LOAD DATA
df <- read_excel("data_layoff.xlsx", sheet = "Tahunan")
df <- as.data.frame(df)

# Nama kolom
colnames(df) <- c(
  "Provinsi", "Tahun", "PHK", "Jml_Bekerja", "UMP", "Growth_UMP", 
  "Upah_Buruh", "Jml_TK_Industri", "PDRB_Riil", "FDI", "IHP", "IHK", 
  "Ekspor", "Impor", "NPL", "BI_Rate", "Kurs", "IKK"
)

# Mengatasi nilai 0 atau NA pada PHK sebelum transformasi Log 
# (Ditambahkan 1 kecil agar log(0) tidak menghasilkan -Inf)
df$PHK_adj <- ifelse(df$PHK == 0 | is.na(df$PHK), 1, df$PHK)

# 3. TRANSFORMASI VARIABEL & PEMBUATAN DATA PANEL (pdata.frame)
# Mengurutkan data berdasarkan panel index
df <- df %>% arrange(Provinsi, Tahun)

# Membuat objek pdata.frame untuk ngolah data panel
pdf <- pdata.frame(df, index = c("Provinsi", "Tahun"))

# Transformasi Log untuk elastisitas
pdf$log_PHK         <- log(pdf$PHK_adj)
pdf$log_Jml_Bekerja <- log(pdf$Jml_Bekerja)
pdf$log_Upah_Buruh  <- log(pdf$Upah_Buruh)
pdf$log_PDRB_Riil   <- log(pdf$PDRB_Riil)
pdf$log_FDI         <- log(ifelse(pdf$FDI <= 0 | is.na(pdf$FDI), 1, pdf$FDI)) # Proteksi log(0)
pdf$log_Ekspor      <- log(ifelse(pdf$Ekspor <= 0 | is.na(pdf$Ekspor), 1, pdf$Ekspor))
pdf$log_Impor       <- log(ifelse(pdf$Impor <= 0 | is.na(pdf$Impor), 1, pdf$Impor))
pdf$log_NPL         <- log(pdf$NPL)
pdf$log_Kurs        <- log(pdf$Kurs)
pdf$log_IKK         <- log(pdf$IKK)

# Transformasi Log Difference (Growth) untuk IHP, IHK, dan PHK
pdf$dlog_IHP        <- diff(log(pdf$IHP))
pdf$dlog_IHK        <- diff(log(pdf$IHK))
pdf$dlog_PHK        <- diff(log(pdf$PHK_adj))

# ------------------------------------------------------------------------------
# PART 1: REGRESI SEDERHANA DATA PANEL (ELASTISITAS)
# ------------------------------------------------------------------------------
# Menggunakan Random Effects (RE) agar variabel makro nasional (BI Rate & Kurs) 
# tidak di-drop secara otomatis oleh model akibat multikolinieritas sempurna.

formula_panel <- log_PHK ~ log_Jml_Bekerja + log_Upah_Buruh + log_PDRB_Riil + 
  log_FDI + dlog_IHP + dlog_IHK + log_Ekspor + 
  log_Impor + log_NPL + BI_Rate + log_Kurs + log_IKK

model_panel_re <- plm(formula_panel, data = pdf, model = "random")

cat("\n--- HASIL REGRESI DATA PANEL (ELASTISITAS LAYOFF) ---\n")
summary(model_panel_re)

# Robust Standard Errors untuk mengantisipasi heteroskedastisitas
cat("\n--- ROBUST STANDARD ERRORS (COEFTEST) ---\n")
coeftest(model_panel_re, vcovHC(model_panel_re, type = "HC1", cluster = "group"))


# ------------------------------------------------------------------------------
# PART 2: KORELASI GROWTH VARIABEL
# ------------------------------------------------------------------------------
# Menghitung selisih log (growth) untuk semua variabel kontinu
df_growth <- df %>%
  group_by(Provinsi) %>%
  mutate(
    g_PHK         = c(NA, diff(log(PHK_adj))),
    g_Jml_Bekerja = c(NA, diff(log(Jml_Bekerja))),
    g_Upah_Buruh  = c(NA, diff(log(Upah_Buruh))),
    g_PDRB_Riil   = c(NA, diff(log(PDRB_Riil))),
    g_FDI         = c(NA, diff(log(ifelse(FDI <= 0 | is.na(FDI), 1, FDI)))),
    g_IHP         = c(NA, diff(log(IHP))),
    g_IHK         = c(NA, diff(log(IHK))),
    g_Ekspor      = c(NA, diff(log(ifelse(Ekspor <= 0 | is.na(Ekspor), 1, Ekspor)))),
    g_Impor       = c(NA, diff(log(ifelse(Impor <= 0 | is.na(Impor), 1, Impor)))),
    g_NPL         = c(NA, diff(log(NPL))),
    g_BI_Rate     = c(NA, diff(BI_Rate)), # BI Rate cukup selisih absolut (perubahan persen)
    g_Kurs        = c(NA, diff(log(Kurs))),
    g_IKK         = c(NA, diff(log(IKK)))
  ) %>%
  ungroup() %>%
  drop_na(g_PHK) # Membuang baris tahun pertama (2022) karena tidak punya nilai growth

# Membuat matriks korelasi growth variabel terhadap growth PHK
growth_cols <- c("g_PHK", "g_Jml_Bekerja", "g_Upah_Buruh", "g_PDRB_Riil", "g_FDI", 
                 "g_IHP", "g_IHK", "g_Ekspor", "g_Impor", "g_NPL", "g_BI_Rate", "g_Kurs", "g_IKK")

cor_matrix <- cor(df_growth[, growth_cols], use = "pairwise.complete.obs")
cat("\n--- MATRIKS KORELASI PERUBAHAN VARIABEL TERHADAP GROWTH PHK ---\n")
print(cor_matrix["g_PHK", , drop = FALSE])


# ------------------------------------------------------------------------------
# PART 3: GRANGER CAUSALITY TEST (DATA PANEL)
# ------------------------------------------------------------------------------
# Karena rentang waktu pendek (2022-2025), lag maksimum yang ideal adalah lag 1.
cat("\n--- DUMITRESCU-HURLIN GRANGER CAUSALITY TEST (LAG = 1) ---\n")

# Menggunakan dlog_PHK untuk memastikan kestasioneran data
tryCatch({
  test_pdrb   <- pgranger(dlog_PHK ~ lag(log_PDRB_Riil, 1), data = pdf, test = "Zbar")
  print("Granger: PDRB Riil -> PHK")
  print(test_pdrb)
}, error = function(e) print("PDRB Granger Test error/tidak cukup derajat kebebasan."))

tryCatch({
  test_birate <- pgranger(dlog_PHK ~ lag(BI_Rate, 1), data = pdf, test = "Zbar")
  print("Granger: BI Rate -> PHK")
  print(test_birate)
}, error = function(e) print("BI Rate Granger Test error/tidak cukup derajat kebebasan."))


# ------------------------------------------------------------------------------
# PART 4: FRACTIONAL LOGIT MODEL (PROBABILITY LAYOFF)
# ------------------------------------------------------------------------------
# Membuat Proportional/Probability Layoff (PHK dibagi Jumlah Penduduk Bekerja)
df$prob_layoff <- df$PHK / df$Jml_Bekerja

# Estimasi Fractional Logit dengan Random Effects menggunakan glmmTMB
model_frac_logit <- glmmTMB(
  prob_layoff ~ Jml_Bekerja + Upah_Buruh + PDRB_Riil + FDI + IHP + IHK + 
    Ekspor + Impor + NPL + BI_Rate + Kurs + IKK + (1 | Provinsi),
  data = df,
  family = binomial(link = "logit")
)

cat("\n--- HASIL ESTIMASI FRACTIONAL LOGIT MODEL ---\n")
summary(model_frac_logit)

# Menghitung Odds Ratio untuk melihat dampak multiplikatif perubahan unit terhadap peluang PHK
cat("\n--- ODDS RATIO VARIABEL INDEPENDEN ---\n")
print(exp(fixef(model_frac_logit)$cond))

# ==============================================================================
# PART 5: ANALISIS KORELASI LEAD VARIABEL MAKRO - GROWTH & DELTA (DATA BULANAN)
# ==============================================================================

# 1. LOAD DATA BULANAN
df_bulan <- read_excel("data_layoff.xlsx", sheet = "Bulanan")
df_bulan <- as.data.frame(df_bulan)

# Nama kolom asli diselaraskan
colnames(df_bulan) <- c(
  "Provinsi", "Tahun", "Bulan", "PHK", "PMI", "IHK", 
  "Ekspor", "Impor", "NPL", "BI_Rate", "Kurs", "Brent", "IHPB"
)

# Memastikan data urut kronologis per provinsi
df_bulan <- df_bulan %>% arrange(Provinsi, Tahun, Bulan)


# 2. PROSES TRANSFORMASI KE GROWTH / DELTA & PEMBUATAN LEAD INDIKATOR
df_lead <- df_bulan %>%
  group_by(Provinsi) %>%
  mutate(
    # A. Transformasi dasar ke MoM Growth (Log Diff) atau Delta (First Diff)
    # Ditambahkan proteksi as.numeric() & penanganan nilai 0/negatif sebelum log
    g_PHK    = c(NA, diff(log(ifelse(as.numeric(PHK) <= 0 | is.na(PHK), 1, as.numeric(PHK))))),
    d_PMI    = c(NA, diff(as.numeric(PMI))),
    g_IHK    = c(NA, diff(log(as.numeric(IHK)))),
    g_Ekspor = c(NA, diff(log(ifelse(as.numeric(Ekspor) <= 0 | is.na(Ekspor), 1, as.numeric(Ekspor))))),
    g_Impor  = c(NA, diff(log(ifelse(as.numeric(Impor) <= 0 | is.na(Impor), 1, as.numeric(Impor))))),
    g_NPL    = c(NA, diff(log(as.numeric(NPL)))),
    d_BI     = c(NA, diff(as.numeric(BI_Rate))),
    g_Kurs   = c(NA, diff(log(as.numeric(Kurs)))),
    g_Brent  = c(NA, diff(log(as.numeric(Brent)))),
    g_IHPB   = c(NA, diff(log(as.numeric(IHPB)))),
    
    # B. Pembuatan Lead dari indikator yang SUDAH bertransformasi (1, 3, dan 6 bulan ke depan)
    # Lead 1 Bulan
    lead1_d_PMI = lead(d_PMI, 1), lead1_g_IHK = lead(g_IHK, 1), lead1_g_Eks = lead(g_Ekspor, 1),
    lead1_g_Imp = lead(g_Impor, 1), lead1_g_NPL = lead(g_NPL, 1), lead1_d_BI  = lead(d_BI, 1),
    lead1_g_Krs = lead(g_Kurs, 1), lead1_g_Brt = lead(g_Brent, 1), lead1_g_IHP = lead(g_IHPB, 1),
    
    # Lead 3 Bulan
    lead3_d_PMI = lead(d_PMI, 3), lead3_g_IHK = lead(g_IHK, 3), lead3_g_Eks = lead(g_Ekspor, 3),
    lead3_g_Imp = lead(g_Impor, 3), lead3_g_NPL = lead(g_NPL, 3), lead3_d_BI  = lead(d_BI, 3),
    lead3_g_Krs = lead(g_Kurs, 3), lead3_g_Brt = lead(g_Brent, 3), lead3_g_IHP = lead(g_IHPB, 3),
    
    # Lead 6 Bulan
    lead6_d_PMI = lead(d_PMI, 6), lead6_g_IHK = lead(g_IHK, 6), lead6_g_Eks = lead(g_Ekspor, 6),
    lead6_g_Imp = lead(g_Impor, 6), lead6_g_NPL = lead(g_NPL, 6), lead6_d_BI  = lead(d_BI, 6),
    lead6_g_Krs = lead(g_Kurs, 6), lead6_g_Brt = lead(g_Brent, 6), lead6_g_IHP = lead(g_IHPB, 6)
  ) %>%
  ungroup() %>%
  filter(!is.na(g_PHK)) # Membuang baris NA pertama hasil diff


# 3. MENGHITUNG MATRIKS KORELASI UNTUK TIAP SKENARIO LEAD
# List nama kolom growth/delta dasar untuk looping
growth_vars <- c("d_PMI", "g_IHK", "g_Ekspor", "g_Impor", "g_NPL", "d_BI", "g_Kurs", "g_Brent", "g_IHPB")

# Suffix variabel untuk memanggil kolom lead di dalam dataframe
lead_suffixes <- c("d_PMI", "g_IHK", "g_Eks", "g_Imp", "g_NPL", "d_BI", "g_Krs", "g_Brt", "g_IHP")

# Storage hasil korelasi yang bersih
korelasi_lead_summary <- data.frame(
  Indikator = c("Delta PMI Manufaktur", "Growth IHK (Inflasi)", "Growth Nilai Ekspor", 
                "Growth Nilai Impor", "Growth NPL", "Delta BI Rate", "Growth Kurs", 
                "Growth Harga Brent", "Growth IHPB"),
  Korelasi_Seketika = NA,
  Lead_1_Bulan = NA,
  Lead_3_Bulan = NA,
  Lead_6_Bulan = NA
)

# Perhitungan korelasi antar perubahan variabel
for(i in 1:length(growth_vars)) {
  v <- growth_vars[i]
  v_short <- lead_suffixes[i]
  
  suppressWarnings({
    korelasi_lead_summary$Korelasi_Seketika[i] <- cor(df_lead$g_PHK, df_lead[[v]], use = "pairwise.complete.obs")
    korelasi_lead_summary$Lead_1_Bulan[i]      <- cor(df_lead$g_PHK, df_lead[[paste0("lead1_", v_short)]], use = "pairwise.complete.obs")
    korelasi_lead_summary$Lead_3_Bulan[i]      <- cor(df_lead$g_PHK, df_lead[[paste0("lead3_", v_short)]], use = "pairwise.complete.obs")
    korelasi_lead_summary$Lead_6_Bulan[i]      <- cor(df_lead$g_PHK, df_lead[[paste0("lead6_", v_short)]], use = "pairwise.complete.obs")
  })
}

# Tampilkan hasil akhir tabel korelasi growth
cat("\n--- RINGKASAN KORELASI GROWTH VARIABEL TERHADAP GROWTH PHK (BULANAN) ---\n")
print(round(korelasi_lead_summary[, -1], 2) %>% 
        mutate(Indikator = korelasi_lead_summary$Indikator) %>% 
        select(Indikator, everything()))

library(openxlsx)
library(dplyr)

# Ambil hasil akhir
korelasi_clean <- korelasi_lead_summary %>%
  mutate(
    # Membulatkan semua nilai korelasi langsung dari objek Anda
    Korelasi_Seketika = round(Korelasi_Seketika, 2),
    Lead_1_Bulan      = round(Lead_1_Bulan, 2),
    Lead_3_Bulan      = round(Lead_3_Bulan, 2),
    Lead_6_Bulan      = round(Lead_6_Bulan, 2),
    
    # Pengelompokan 3 kategori variabel
    Kategori = case_when(
      Indikator == "Growth Harga Brent" ~ "1. Variabel Global",
      Indikator %in% c("Delta BI Rate", "Growth Kurs") ~ "2. Variabel Nasional",
      TRUE ~ "3. Variabel Provinsial"
    )
  ) %>%
  # Mengurutkan berdasarkan kategori agar rapi saat disusun di Excel
  arrange(Kategori, Indikator) %>%
  select(Kategori, Indikator, everything())

# Simpan ke Excel
write.xlsx(korelasi_clean, "Korelasi_Lead_PHK_Clean.xlsx", 
           sheetName = "Korelasi Bulanan", 
           keepNA = TRUE, 
           asTable = TRUE, 
           tableStyle = "TableStyleMedium2")

# ==============================================================================
# FRACTIONAL LOGIT MODEL DENGAN DATA BULANAN (GROWTH & DELTA)
# ==============================================================================

library(readxl)
library(dplyr)
library(glmmTMB)

# 1. LOAD DATA TAHUNAN DAN BULANAN
df_tahun <- read_excel("data_layoff.xlsx", sheet = "Tahunan")
df_bulan <- read_excel("data_layoff.xlsx", sheet = "Bulanan")

# Sederhanakan nama kolom tahunan untuk mengambil basis pekerja
colnames(df_tahun) <- c(
  "Provinsi", "Tahun", "PHK_T", "Jml_Bekerja", "UMP", "Growth_UMP", 
  "Upah_Buruh", "Jml_TK_Industri", "PDRB_Riil", "FDI", "IHP", "IHK", 
  "Ekspor", "Impor", "NPL", "BI_Rate", "Kurs", "IKK"
)
base_pekerja <- df_tahun %>% select(Provinsi, Tahun, Jml_Bekerja)

# Sederhanakan nama kolom bulanan
colnames(df_bulan) <- c(
  "Provinsi", "Tahun", "Bulan", "PHK", "PMI", "IHK", 
  "Ekspor", "Impor", "NPL", "BI_Rate", "Kurs", "Brent", "IHPB"
)

# 2. PENGGABUNGAN DATA & INTERPOLASI BASIS PEKERJA
df_gabungan <- df_bulan %>%
  left_join(base_pekerja, by = c("Provinsi", "Tahun")) %>%
  arrange(Provinsi, Tahun, Bulan) %>%
  group_by(Provinsi) %>%
  # Jika data Jml_Bekerja tahun 2025 belum rilis di sheet tahunan, lakukan forward-fill
  tidyr::fill(Jml_Bekerja, .direction = "down") %>%
  ungroup()

# Pastikan PHK tidak ada yang NA atau karakter teks sebelum dibagi
df_gabungan$PHK <- as.numeric(ifelse(is.na(df_gabungan$PHK) | df_gabungan$PHK == "-", 0, df_gabungan$PHK))

# Membuat variabel dependen: Probability Layoff (PHK / Jumlah Penduduk Bekerja)
df_gabungan$prob_layoff <- df_gabungan$PHK / df_gabungan$Jml_Bekerja


# 3. TRANSFORMASI VARIABEL INDEPENDEN KE MODEL PERUBAHAN (GROWTH / DELTA)
df_model_input <- df_gabungan %>%
  arrange(Provinsi, Tahun, Bulan) %>%
  group_by(Provinsi) %>%
  mutate(
    # Transformasi variabel ke tingkat perubahan (MoM Growth atau Delta)
    d_PMI    = c(NA, diff(as.numeric(PMI))),
    g_IHK    = c(NA, diff(log(as.numeric(IHK)))),
    g_Ekspor = c(NA, diff(log(ifelse(as.numeric(Ekspor) <= 0 | is.na(Ekspor), 1, as.numeric(Ekspor))))),
    g_Impor  = c(NA, diff(log(ifelse(as.numeric(Impor) <= 0 | is.na(Impor), 1, as.numeric(Impor))))),
    g_NPL    = c(NA, diff(log(as.numeric(NPL)))),
    g_Kurs   = c(NA, diff(log(as.numeric(Kurs)))),
    g_Brent  = c(NA, diff(log(as.numeric(Brent)))),
    g_IHPB   = c(NA, diff(log(as.numeric(IHPB)))),
    
    # MENGATASI BI_RATE (Variabel Nasional): Diinteraksikan dengan g_NPL tingkat provinsi
    d_BI_Rate       = c(NA, diff(as.numeric(BI_Rate))),
    d_BI_interaksi  = d_BI_Rate * g_NPL
  ) %>%
  ungroup() %>%
  # Buang baris pertama per provinsi karena menghasilkan NA pada fungsi diff()
  filter(!is.na(g_IHK))


# 4. ESTIMASI MODEL FRACTIONAL LOGIT DENGAN RANDOM EFFECTS
# Kita tidak lagi memasukkan data level asli, melainkan seluruhnya dalam bentuk perubahan.
model_frac_bulanan <- glmmTMB(
  prob_layoff ~ d_PMI + g_IHK + g_Ekspor + g_Impor + g_NPL + g_Kurs + g_Brent + g_IHPB + d_BI_interaksi + (1 | Provinsi),
  data = df_model_input,
  family = binomial(link = "logit")
)

# 5. TAMPILKAN HASILNYA
cat("\n--- RELEVANSI KOEFISIEN FRACTIONAL LOGIT (BULANAN) ---\n")
summary(model_frac_bulanan)

cat("\n--- ODDS RATIO MODEL (BENTUK GROWTH & DELTA) ---\n")
print(exp(fixef(model_frac_bulanan)$cond))

# ==============================================================================
# INDIVIDUAL PROVINCE MODELS (PROBABILITY MATRIX, FORECAST, & LATEST DATA SUMMARY)
# ==============================================================================

library(dplyr)
library(tidyr)
library(openxlsx)

daftar_provinsi <- unique(df_model_input$Provinsi)

# data storage
tabel_prob_komplit <- data.frame()
tabel_proyeksi_terkini <- data.frame()
tabel_variabel_terkini <- data.frame() # storage untuk sheet ke-3

# Mulai Looping 38 Provinsi
for (prov in daftar_provinsi) {
  
  data_sub <- df_model_input %>% filter(Provinsi == prov)
  
  if (sd(data_sub$prob_layoff, na.rm = TRUE) > 0) {
    
    # Run Model Fractional Logit per Provinsi
    model_prov <- tryCatch({
      glm(
        prob_layoff ~ d_PMI + g_IHK + g_Ekspor + g_Impor + g_NPL + g_Kurs + g_Brent + g_IHPB + d_BI_Rate, 
        data = data_sub, 
        family = quasibinomial(link = "logit")
      )
    }, error = function(e) { NULL })
    
    if (!is.null(model_prov)) {
      
      # 1. HITUNG MARGINAL EFFECT YANG VALID (PERSENTASE POIN / pp)
      coef_val <- coef(model_prov)
      p_val    <- summary(model_prov)$coefficients[, 4]
      P_base   <- mean(data_sub$prob_layoff, na.rm = TRUE)
      
      to_prob_effect <- function(var_name) {
        if(!var_name %in% names(coef_val) || is.na(coef_val[var_name])) return("0.00 pp")
        marginal_effect <- coef_val[var_name] * P_base * (1 - P_base)
        eff_pct <- marginal_effect * 100
        sig <- ifelse(p_val[var_name] < 0.05, "*", "")
        return(paste0(round(eff_pct, 2), " pp", sig))
      }
      
      hasil_prov <- data.frame(
        Provinsi       = prov,
        Efek_d_PMI     = to_prob_effect("d_PMI"),
        Efek_g_IHK     = to_prob_effect("g_IHK"),
        Efek_g_Ekspor  = to_prob_effect("g_Ekspor"),
        Efek_g_Impor   = to_prob_effect("g_Impor"),
        Efek_g_NPL     = to_prob_effect("g_NPL"),
        Efek_g_Kurs    = to_prob_effect("g_Kurs"),
        Efek_g_Brent   = to_prob_effect("g_Brent"),
        Efek_g_IHPB    = to_prob_effect("g_IHPB"),
        Efek_d_BI_Rate = to_prob_effect("d_BI_Rate")
      )
      tabel_prob_komplit <- rbind(tabel_prob_komplit, hasil_prov)
      
      # 2. PROYEKSI PROBABILITAS LAYOFF DAN JUMLAH ORANG BERDASARKAN DATA TERKINI
      data_terkini <- data_sub %>% tail(1)
      
      if (nrow(data_terkini) > 0) {
        log_odds_pred <- predict(model_prov, newdata = data_terkini, type = "link")
        prob_aktual <- 1 / (1 + exp(-log_odds_pred))
        estimasi_orang_phk <- prob_aktual * data_terkini$Jml_Bekerja
        
        hasil_proyeksi <- data.frame(
          Provinsi                     = prov,
          Tahun_Data                   = data_terkini$Tahun,
          Bulan_Data                   = data_terkini$Bulan,
          Jumlah_Penduduk_Bekerja      = round(data_terkini$Jml_Bekerja, 0),
          Probabilitas_Layoff_Aktual   = round(prob_aktual, 6), 
          Persentase_Risiko            = paste0(round(prob_aktual * 100, 2), "%"), 
          Prediksi_Jumlah_PHK_Orang    = round(estimasi_orang_phk, 0)
        )
        tabel_proyeksi_terkini <- rbind(tabel_proyeksi_terkini, hasil_proyeksi)
        
        # 3. AMBIL DATA HISTORIS KONDISI VARIABEL TERKINI (SUDAH 2 DIGIT ROUND)
        # Menampilkan angka growth/delta aktual di bulan terakhir yang masuk ke persamaan model
        hasil_var_terkini <- data.frame(
          Provinsi       = prov,
          Tahun_Data     = data_terkini$Tahun,
          Bulan_Data     = data_terkini$Bulan,
          Delta_PMI      = round(as.numeric(data_terkini$d_PMI), 2),
          Growth_IHK     = paste0(round(as.numeric(data_terkini$g_IHK) * 100, 2), "%"),
          Growth_Ekspor  = paste0(round(as.numeric(data_terkini$g_Ekspor) * 100, 2), "%"),
          Growth_Impor   = paste0(round(as.numeric(data_terkini$g_Impor) * 100, 2), "%"),
          Growth_NPL     = paste0(round(as.numeric(data_terkini$g_NPL) * 100, 2), "%"),
          Growth_Kurs    = paste0(round(as.numeric(data_terkini$g_Kurs) * 100, 2), "%"),
          Growth_Brent   = paste0(round(as.numeric(data_terkini$g_Brent) * 100, 2), "%"),
          Growth_IHPB    = paste0(round(as.numeric(data_terkini$g_IHPB) * 100, 2), "%"),
          Delta_BI_Rate  = round(as.numeric(data_terkini$d_BI_Rate), 2)
        )
        tabel_variabel_terkini <- rbind(tabel_variabel_terkini, hasil_var_terkini)
      }
    }
  }
}

# ==============================================================================
# EKSPOR EXCEL 3 SHEETS (COMPLETE DASHBOARD SOURCE)
# ==============================================================================

wb <- createWorkbook()
addWorksheet(wb, "Dampak Probabilitas Variabel")
addWorksheet(wb, "Proyeksi Risiko Terkini")
addWorksheet(wb, "Kondisi Variabel Terkini") # Sheet Baru

# Write data menggunakan format tabel otomatis yang rapi
writeDataTable(wb, "Dampak Probabilitas Variabel", tabel_prob_komplit, tableStyle = "TableStyleMedium2")
writeDataTable(wb, "Proyeksi Risiko Terkini", tabel_proyeksi_terkini, tableStyle = "TableStyleMedium2")
writeDataTable(wb, "Kondisi Variabel Terkini", tabel_variabel_terkini, tableStyle = "TableStyleMedium2")

# Autofit lebar kolom agar tidak terpotong (###) di Excel
setColWidths(wb, "Dampak Probabilitas Variabel", cols = 1:ncol(tabel_prob_komplit), widths = "auto")
setColWidths(wb, "Proyeksi Risiko Terkini", cols = 1:ncol(tabel_proyeksi_terkini), widths = "auto")
setColWidths(wb, "Kondisi Variabel Terkini", cols = 1:ncol(tabel_variabel_terkini), widths = "auto")

saveWorkbook(wb, "Analisis_Probabilitas_Layoff_Provinsi.xlsx", overwrite = TRUE)
cat("\n[Sukses Master!] 3 Sheet komplit berhasil diekspor ke 'Analisis_Probabilitas_Layoff_Provinsi.xlsx'\n")
