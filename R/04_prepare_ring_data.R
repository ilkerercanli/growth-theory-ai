# =============================================================================
# ITRDB HALKA GENİŞLİKLERİNİ MODEL İÇİN HAZIRLAMA
# Girdi : ITRDB_envanter/4_itrdb_seri_ozeti.csv, RWL/*.rwl, IKLIM/alan_iklim_ozet.csv
# Çıktı : ITRDB_envanter/HAZIR/
#   halka/part_XXXX.parquet : seri_uid, year, rw_mm, r_onceki_mm   (1901–2024)
#   seri_meta.csv           : seri başına bilgiler + test grupları
#   alan_meta.csv           : alan başına bilgiler + iklim normalleri
#   elenen_seriler.csv      : modele girmeyen seriler ve nedeni
#
# ÖNEMLİ: ITRDB'de bir alanın birden fazla .rwl dosyası olabilir. Yalnız TOPLAM halka
# genişliği kullanılır: sonek yok (ör. cana426.rwl) ya da yalnız "w" varsa (mong007w.rwl).
# e = ilkbahar odunu, l = yaz odunu, x/n/i/t/p/d/b... = yoğunluk ve diğer ölçümler -> HARİÇ.
#
# r_onceki_mm: serinin ilk ölçülen halkasından o yılın başına kadar birikmiş yarıçap.
# Öz (pith) bilinmediği için gerçek yarıçap = r0 + r_onceki_mm; r0 modelde gizil parametredir.
# Prof. Dr. İlker Ercanlı — taslak betik, Ekim 2026
# =============================================================================

for (pk in c("dplR", "data.table", "arrow")) {
  if (!requireNamespace(pk, quietly = TRUE)) install.packages(pk, repos = "https://cloud.r-project.org")
}
suppressPackageStartupMessages({ library(dplR); library(data.table) })
PARQUET <- requireNamespace("arrow", quietly = TRUE)

# ---- Ayarlar ----------------------------------------------------------------
ANA_DIR    <- "D:/ITRDB_envanter"
RWL_DIR    <- file.path(ANA_DIR, "RWL")
OUT_DIR    <- file.path(ANA_DIR, "HAZIR")
YILLAR     <- c(1901, 2024)      # CRU dönemi
MIN_HALKA  <- 50                 # CRU döneminde en az bu kadar halka
MAX_RW     <- 20                 # mm; üstü ölçüm hatası sayılır (NA yapılır)
PARCA      <- 300                # her parquet parçasındaki dosya sayısı
HARIC_ALANLAR <- c("CO700", "CO701", "CO702", "WY054", "WY055")
TAKSON_TEST   <- c("Larix", "Fagus", "Cedrus", "Nothofagus")   # eğitimde hiç görülmeyecek cinsler

dir.create(file.path(OUT_DIR, "halka"), recursive = TRUE, showWarnings = FALSE)
t_bas <- Sys.time()

# ---- 1. Dosya seçimi: yalnız toplam halka genişliği -------------------------
oz <- fread(file.path(ANA_DIR, "4_itrdb_seri_ozeti.csv"), encoding = "UTF-8")
oz <- oz[durum == "tamam" & !(studyCode %in% HARIC_ALANLAR)]
oz[, taban := tolower(sub("\\.rwl$", "", basename(rwl_url), ignore.case = TRUE))]
oz[, sonek := ifelse(startsWith(taban, tolower(studyCode)), substring(taban, nchar(studyCode) + 1), "?")]
oz[, sec := (sonek == "") | (sonek == "w" & !any(sonek == "")), by = studyCode]
cat(sprintf("Toplam %d dosya; toplam halka genişliği dosyası: %d (diğerleri ilkbahar/yaz odunu veya yoğunluk)\n",
            nrow(oz), sum(oz$sec)))
oz <- oz[sec == TRUE]
oz[, yerel := file.path(RWL_DIR, paste0(NOAAStudyId, "_", basename(rwl_url)))]

# ---- 2. Okuma ve uzun tabloya çevirme ---------------------------------------
seri_isle <- function(rw, sc) {
  yil <- as.integer(rownames(rw))
  m <- as.matrix(rw); m[m < 0] <- NA
  uzun <- vector("list", ncol(m)); meta <- vector("list", ncol(m))
  for (j in seq_len(ncol(m))) {
    v <- m[, j]; ok <- which(!is.na(v))
    if (length(ok) == 0) next
    a <- min(ok); b <- max(ok); vv <- v[a:b]; yy <- yil[a:b]
    asiri <- sum(vv > MAX_RW, na.rm = TRUE); vv[!is.na(vv) & vv > MAX_RW] <- NA
    r_onc <- cumsum(c(0, ifelse(is.na(vv), 0, vv)))[seq_along(vv)]   # yıl başındaki birikmiş yarıçap
    k <- yy >= YILLAR[1] & yy <= YILLAR[2]
    uid <- paste(sc, colnames(m)[j], sep = "__")
    meta[[j]] <- data.table(seri_uid = uid, studyCode = sc, seri_kodu = colnames(m)[j],
      ilk_yil = yy[1], son_yil = yy[length(yy)], n_halka = sum(!is.na(vv)),
      n_halka_cru = sum(!is.na(vv[k])), ic_eksik = sum(is.na(vv)), asiri_deger = asiri,
      sifir_halka = sum(vv == 0, na.rm = TRUE),
      n_once_1960 = sum(!is.na(vv[k & yy <= 1960])), n_sonra_1960 = sum(!is.na(vv[k & yy > 1960])),
      r_cru_basi_mm = if (any(k)) r_onc[which(k)[1]] else NA_real_)
    if (any(k)) uzun[[j]] <- data.table(seri_uid = uid, year = yy[k], rw_mm = vv[k], r_onceki_mm = r_onc[k])
  }
  list(uzun = rbindlist(uzun), meta = rbindlist(meta))
}

parcalar <- split(seq_len(nrow(oz)), ceiling(seq_len(nrow(oz)) / PARCA))
tum_meta <- list(); n_satir <- 0
for (p in seq_along(parcalar)) {
  U <- list(); M <- list()
  for (i in parcalar[[p]]) {
    rw <- tryCatch({ invisible(capture.output(x <- suppressWarnings(suppressMessages(
            read.rwl(oz$yerel[i], format = "tucson"))))); x }, error = function(e) NULL)
    if (is.null(rw) || ncol(rw) == 0) next
    s <- seri_isle(rw, oz$studyCode[i]); U[[length(U) + 1]] <- s$uzun; M[[length(M) + 1]] <- s$meta
  }
  M <- rbindlist(M); U <- rbindlist(U)
  M[, modele_girer := n_halka_cru >= MIN_HALKA]
  U <- U[seri_uid %in% M[modele_girer == TRUE, seri_uid] & !is.na(rw_mm)]
  hedef <- file.path(OUT_DIR, "halka", sprintf("part_%04d.%s", p, if (PARQUET) "parquet" else "csv.gz"))
  if (PARQUET) arrow::write_parquet(U, hedef) else fwrite(U, hedef)
  tum_meta[[p]] <- M; n_satir <- n_satir + nrow(U)
  gecen <- as.numeric(difftime(Sys.time(), t_bas, units = "mins"))
  cat(sprintf("Parça %d / %d tamam (%d dosya, %.0f dk geçti, tahmini kalan %.0f dk)\n",
              p, length(parcalar), max(parcalar[[p]]), gecen, gecen / p * (length(parcalar) - p)))
}

# ---- 3. Seri ve alan bilgileri ------------------------------------------------
meta <- rbindlist(tum_meta)
fwrite(meta[modele_girer == FALSE, .(seri_uid, studyCode, n_halka_cru,
        neden = sprintf("CRU döneminde %d'den az halka", MIN_HALKA))], file.path(OUT_DIR, "elenen_seriler.csv"))
meta <- meta[modele_girer == TRUE][, modele_girer := NULL]
meta[, agac_kodu_tahmini := paste(studyCode, substr(seri_kodu, 1, nchar(seri_kodu) - 1), sep = "__")]

iklim <- fread(file.path(ANA_DIR, "IKLIM", "alan_iklim_ozet.csv"), encoding = "UTF-8")
alan <- unique(oz[, .(studyCode, NOAAStudyId, scientificName, genus, continent, lat, lon, rwl_dosyasi = basename(rwl_url))], by = "studyCode")
alan <- merge(alan, iklim[, !c("lat", "lon", "genus", "scientificName", "continent", "ix", "iy")], by = "studyCode", all.x = TRUE)

# Kıta adlarını düzelt ("Ocean>...>Cyprus" gibi kayıtlar)
kita_duz <- function(k) {
  if (!startsWith(k, "Ocean")) return(k)
  son <- tail(strsplit(k, ">")[[1]], 1)
  switch(son, Cyprus = "Asia", Corsica = "Europe", Bahamas = "North America",
         Philippines = "Asia", Indonesia = "Asia", "Jawa Timur" = "Asia", son)
}
alan[, kita := vapply(continent, kita_duz, "")]
alan[, blok_10 := sprintf("%+03d_%+04d", floor(lat / 10) * 10, floor(lon / 10) * 10)]   # 10° mekânsal blok
alan[, takson_test := genus %in% TAKSON_TEST]
alan <- alan[studyCode %in% meta$studyCode]

meta <- merge(meta, alan[, .(studyCode, genus, scientificName, kita, blok_10, takson_test)], by = "studyCode")
meta[, zaman_test_uygun := n_once_1960 >= 20 & n_sonra_1960 >= 20]    # 1960 öncesi eğitim / sonrası test
fwrite(meta, file.path(OUT_DIR, "seri_meta.csv"))
fwrite(alan, file.path(OUT_DIR, "alan_meta.csv"))

# ---- 4. Özet -------------------------------------------------------------------
cat("\n==== VERİ HAZIRLAMA TAMAM ====\n")
cat("Alan                      :", nrow(alan), "\n")
cat("Tür / cins                :", uniqueN(alan$scientificName), "/", uniqueN(alan$genus), "\n")
cat("Seri (modele giren)       :", nrow(meta), "\n")
cat("Tahmini ağaç              :", uniqueN(meta$agac_kodu_tahmini), "\n")
cat("Halka (1901–2024)         :", n_satir, "\n")
cat("1960 testine uygun seri   :", sum(meta$zaman_test_uygun), "\n")
cat("Takson testi serisi       :", sum(meta$takson_test), "(", paste(TAKSON_TEST, collapse = ", "), ")\n")
cat("Aşırı değer (NA yapılan)  :", sum(meta$asiri_deger), "halka\n")
cat("Kıtalara göre seri:\n"); print(meta[, .N, by = kita][order(-N)])
cat("Dosya biçimi              :", if (PARQUET) "parquet" else "csv.gz (arrow kurulamadı)", "\n")
cat("Süre:", round(as.numeric(difftime(Sys.time(), t_bas, units = "mins")), 1), "dk\n")
