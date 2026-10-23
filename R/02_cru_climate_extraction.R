# =============================================================================
# CRU TS4.09 İKLİMİNİ ITRDB ALANLARINA AKTARMA
# Girdi : ITRDB_envanter/1_itrdb_dosyalar.csv  (envanter betiğinin çıktısı)
#         ITRDB_envanter/CRU/cru_ts4.09.1901.2024.{tmp,pre,pet,vap}.dat.nc.gz
# Çıktı : ITRDB_envanter/IKLIM/
#   iklim_aylik.csv.gz     : alan × yıl × ay; tmp (°C), pre (mm/ay), pet (mm/ay),
#                            vap (hPa), vpd (kPa), stn_tmp, stn_pre (istasyon sayısı)
#   alan_iklim_ozet.csv    : alan başına 1901–1960 iklim normalleri, kuraklık indeksi,
#                            istasyon kapsamı ve kullanılan CRU hücresi
#
# Yöntem: Her alan en yakın 0,5° CRU hücresine atanır. Hücre denizdeyse (değer yok),
# 1° (2 hücre) içindeki en yakın kara hücresi kullanılır; bulunamazsa alan işaretlenir.
# Okuma, her enlem satırı için tek seferde yapılır (hızlı).
# Prof. Dr. İlker Ercanlı — taslak betik, Ekim 2026
# =============================================================================

for (pk in c("ncdf4", "R.utils")) {
  if (!requireNamespace(pk, quietly = TRUE)) install.packages(pk, repos = "https://cloud.r-project.org")
}
library(ncdf4)

# ---- Ayarlar ----------------------------------------------------------------
ANA_DIR   <- "C:/Users/ercan/Desktop/ITRDB_envanter"
CRU_DIR   <- file.path(ANA_DIR, "CRU")
OUT_DIR   <- file.path(ANA_DIR, "IKLIM")
SURUM     <- "cru_ts4.09.1901.2024"
DEGISKEN  <- c("tmp", "pre", "pet", "vap")
NORMAL    <- c(1901, 1960)                     # iklim normali dönemi (Methods ile aynı)
HARIC_ALANLAR <- c("CO700", "CO701", "CO702", "WY054", "WY055")
GZ_SIL    <- FALSE   # TRUE: .nc açıldıktan sonra .gz dosyalarını sil (yer kazanmak için)

dir.create(OUT_DIR, showWarnings = FALSE)
t_bas <- Sys.time()

# ---- 1. Alanlar ----------------------------------------------------------------
d <- read.csv(file.path(ANA_DIR, "1_itrdb_dosyalar.csv"), fileEncoding = "UTF-8", stringsAsFactors = FALSE)
d <- d[d$cru_uygun & !(d$studyCode %in% HARIC_ALANLAR) & !is.na(d$lat) & !is.na(d$lon), ]
alan <- d[!duplicated(d$studyCode), c("studyCode", "lat", "lon", "elev_m", "genus", "scientificName", "continent")]
alan <- alan[abs(alan$lat) <= 90 & abs(alan$lon) <= 180, ]
message(sprintf("İklim aktarılacak alan sayısı: %d", nrow(alan)))

# ---- 2. Sıkıştırılmış dosyaları aç (.gz -> .nc) -------------------------------
# Her .nc dosyası yaklaşık 1,5–3 GB'tır; toplamda ~10 GB boş disk gerekir.
nc_yol <- setNames(file.path(CRU_DIR, paste0(SURUM, ".", DEGISKEN, ".dat.nc")), DEGISKEN)
for (v in DEGISKEN) {
  gz <- paste0(nc_yol[v], ".gz")
  if (!file.exists(nc_yol[v])) {
    if (!file.exists(gz)) stop("Dosya bulunamadı: ", gz)
    message(sprintf("%s açılıyor (birkaç dakika sürebilir)...", basename(gz)))
    R.utils::gunzip(gz, destname = nc_yol[v], remove = GZ_SIL, overwrite = FALSE)
  }
}

# ---- 3. Izgara ve zaman ---------------------------------------------------------
nc0  <- nc_open(nc_yol["tmp"])
lonv <- ncvar_get(nc0, "lon"); latv <- ncvar_get(nc0, "lat")
nt   <- nc0$dim$time$len
nc_close(nc0)
yil <- rep(1901:(1901 + nt / 12 - 1), each = 12); ay <- rep(1:12, times = nt / 12)
stopifnot(length(yil) == nt)
message(sprintf("CRU ızgarası: %d boylam × %d enlem, %d ay (%d–%d)", length(lonv), length(latv), nt, min(yil), max(yil)))

alan$ix <- vapply(alan$lon, function(x) which.min(abs(lonv - x)), 1L)
alan$iy <- vapply(alan$lat, function(y) which.min(abs(latv - y)), 1L)

# ---- 4. Okuma: her enlem satırı bir kez okunur ----------------------------------
oku_degisken <- function(yol, varad) {
  nc <- nc_open(yol); on.exit(nc_close(nc))
  out <- matrix(NA_real_, nrow(alan), nt)
  for (iy in sort(unique(alan$iy))) {
    satir <- ncvar_get(nc, varad, start = c(1, iy, 1), count = c(-1, 1, -1))  # [lon, time]
    k <- which(alan$iy == iy)
    out[k, ] <- satir[alan$ix[k], , drop = FALSE]
  }
  out
}
# Deniz hücresine düşen alanlar için 1° içindeki en yakın kara hücresi
komsu_ara <- function(yol, varad, i) {
  nc <- nc_open(yol); on.exit(nc_close(nc))
  en_iyi <- NULL; en_d <- Inf
  for (dy in -2:2) for (dx in -2:2) {
    iy <- alan$iy[i] + dy; ix <- alan$ix[i] + dx
    if (iy < 1 || iy > length(latv) || ix < 1 || ix > length(lonv)) next
    z <- ncvar_get(nc, varad, start = c(ix, iy, 1), count = c(1, 1, -1))
    if (all(is.na(z))) next
    dd <- (latv[iy] - alan$lat[i])^2 + ((lonv[ix] - alan$lon[i]) * cos(alan$lat[i] * pi / 180))^2
    if (dd < en_d) { en_d <- dd; en_iyi <- list(ix = ix, iy = iy) }
  }
  en_iyi
}

# Önce sıcaklık okunur; deniz hücreleri bulunur ve komşu kara hücresine taşınır
message("Sıcaklık okunuyor...")
X <- list(); X$tmp <- oku_degisken(nc_yol["tmp"], "tmp")
deniz <- which(rowSums(!is.na(X$tmp)) == 0)
alan$hucre_tasindi <- FALSE; alan$iklim_yok <- FALSE
if (length(deniz) > 0) {
  message(sprintf("%d alan deniz hücresine düştü; komşu kara hücresi aranıyor...", length(deniz)))
  for (i in deniz) {
    h <- komsu_ara(nc_yol["tmp"], "tmp", i)
    if (is.null(h)) { alan$iklim_yok[i] <- TRUE } else { alan$ix[i] <- h$ix; alan$iy[i] <- h$iy; alan$hucre_tasindi[i] <- TRUE }
  }
  X$tmp <- oku_degisken(nc_yol["tmp"], "tmp")
}
alan$cru_lon <- lonv[alan$ix]; alan$cru_lat <- latv[alan$iy]

for (v in setdiff(DEGISKEN, "tmp")) { message(sprintf("%s okunuyor...", v)); X[[v]] <- oku_degisken(nc_yol[v], v) }
message("İstasyon sayıları okunuyor (veri kalitesi göstergesi)...")
stn_tmp <- oku_degisken(nc_yol["tmp"], "stn")
stn_pre <- oku_degisken(nc_yol["pre"], "stn")

# ---- 5. Birim dönüşümleri ve VPD ------------------------------------------------
gun <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
gun_t <- gun[ay] + ifelse(ay == 2 & ((yil %% 4 == 0 & yil %% 100 != 0) | yil %% 400 == 0), 1, 0)
nc_p <- nc_open(nc_yol["pet"]); pet_birim <- ncatt_get(nc_p, "pet", "units")$value; nc_close(nc_p)
message("PET birimi dosyada: ", pet_birim)
if (grepl("day", pet_birim, ignore.case = TRUE)) X$pet <- sweep(X$pet, 2, gun_t, "*")   # mm/gün -> mm/ay
# VPD (kPa): doygun buhar basıncı aylık ortalama sıcaklıktan (Tetens), gerçek buhar basıncı vap (hPa)
es  <- 0.6108 * exp(17.27 * X$tmp / (X$tmp + 237.3))
vpd <- pmax(es - X$vap / 10, 0)

# ---- 6. Yazma -------------------------------------------------------------------
message("Aylık tablo yazılıyor (iklim_aylik.csv.gz)...")
uzun <- data.frame(
  studyCode = rep(alan$studyCode, times = nt),
  year = rep(yil, each = nrow(alan)), month = rep(ay, each = nrow(alan)),
  tmp = round(as.vector(X$tmp), 2), pre = round(as.vector(X$pre), 1),
  pet = round(as.vector(X$pet), 1), vap = round(as.vector(X$vap), 2),
  vpd = round(as.vector(vpd), 3),
  stn_tmp = as.vector(stn_tmp), stn_pre = as.vector(stn_pre))
uzun <- uzun[!is.na(uzun$tmp), ]
gz <- gzfile(file.path(OUT_DIR, "iklim_aylik.csv.gz"), "w")
write.csv(uzun, gz, row.names = FALSE); close(gz)

# Alan özeti: 1901–1960 normalleri + istasyon kapsamı
nrm <- yil >= NORMAL[1] & yil <= NORMAL[2]
yillik <- function(M, f) rowMeans(sapply(split(seq_len(nt)[nrm], yil[nrm]), function(j) apply(M[, j, drop = FALSE], 1, f)))
alan$T_ort_normal   <- round(rowMeans(X$tmp[, nrm], na.rm = TRUE), 2)
alan$P_yil_normal   <- round(yillik(X$pre, sum), 0)
alan$PET_yil_normal <- round(yillik(X$pet, sum), 0)
alan$kuraklik_P_PET <- round(alan$P_yil_normal / alan$PET_yil_normal, 3)    # UNEP kuraklık indeksi
alan$VPD_ort_normal <- round(rowMeans(vpd[, nrm], na.rm = TRUE), 3)
alan$istasyonsuz_ay_orani_tmp <- round(rowMeans(stn_tmp == 0, na.rm = TRUE), 3)
alan$istasyonsuz_ay_orani_pre <- round(rowMeans(stn_pre == 0, na.rm = TRUE), 3)
write.csv(alan, file.path(OUT_DIR, "alan_iklim_ozet.csv"), row.names = FALSE, fileEncoding = "UTF-8")

cat("\n==== İKLİM AKTARIMI TAMAM ====\n")
cat("Alan                    :", nrow(alan), "\n")
cat("Komşu hücreye taşınan   :", sum(alan$hucre_tasindi), "\n")
cat("İklim bulunamayan alan  :", sum(alan$iklim_yok), "\n")
cat("Aylık satır sayısı      :", nrow(uzun), "\n")
cat("Ort. sıcaklık normali   :", round(mean(alan$T_ort_normal, na.rm = TRUE), 1), "°C\n")
cat("Medyan istasyonsuz ay (yağış):", median(alan$istasyonsuz_ay_orani_pre, na.rm = TRUE), "\n")
cat("Süre:", round(as.numeric(difftime(Sys.time(), t_bas, units = "mins")), 1), "dk\n")

# NOTLAR
# - stn = 0 olan aylarda CRU değeri istasyon gözlemine değil iklim normaline dayanır.
#   Modelde bu aylar düşük ağırlıklı ya da hariç tutulabilir (Methods'a eklenecek).
# - VPD, aylık ortalama sıcaklıktan hesaplandığı için günlük VPD'nin ortalamasından
#   sistematik olarak düşüktür; göreli karşılaştırmalar için yeterlidir.
# - CRU TS verisi UK Open Government Licence v3 kapsamındadır; atıf:
#   Harris et al. (2020) Sci. Data 7, 109 ve CEDA veri kaydı (CRU TS4.09).
