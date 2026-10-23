# =============================================================================
# YETİŞME ORTAMI DEĞİŞKENLERİ: toprak, topoğrafya, ekolojik bölge, Köppen–Geiger
# Girdi : ITRDB_envanter/HAZIR/alan_meta.csv  (6.294 alan)
# Çıktı : ITRDB_envanter/ORTAM/alan_ortam.csv  + kaynaklar_ve_lisanslar.txt
#
# Kaynaklar (hepsi açık lisanslı; erişim tarihi kaynaklar dosyasına yazılır):
#  - SoilGrids 2.0, 1 km toplulaştırılmış katmanlar (ISRIC; CC BY 4.0) — internetten noktasal okunur, indirme yok
#  - Copernicus DEM GLO-90 (ESA/Copernicus; serbest lisans, atıf gerekli) — AWS açık veri, noktasal okunur
#  - RESOLVE Ecoregions 2017 (Dinerstein ve ark. 2017; CC BY 4.0) — zip dosyası (otomatik ya da elle indirilir)
#  - Köppen–Geiger 1 km (Beck ve ark. 2023, Scientific Data) — koppen_geiger_tif.zip (elle indirilir)
#
# Ölçek notu: ITRDB koordinatları çoğunlukla ~1 km hassasiyettedir. Bu yüzden toprak 1 km katmanlardan,
# topoğrafya ise noktanın çevresindeki ~1 km yarıçaplı pencereden özetlenir (tek piksel değil).
# Betik kaldığı yerden devam eder: her aşama ORTAM/ara_*.rds olarak kaydedilir.
# Prof. Dr. İlker Ercanlı — taslak betik, Ekim 2026
# =============================================================================

for (pk in c("terra", "data.table")) if (!requireNamespace(pk, quietly = TRUE)) install.packages(pk, repos = "https://cloud.r-project.org")
suppressPackageStartupMessages({ library(terra); library(data.table) })
terraOptions(progress = 0)
setGDALconfig("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
setGDALconfig("CPL_VSIL_CURL_ALLOWED_EXTENSIONS", ".tif,.vrt")
setGDALconfig("GDAL_HTTP_MAX_RETRY", "5"); setGDALconfig("GDAL_HTTP_RETRY_DELAY", "3")

ANA_DIR <- "D:/ITRDB_envanter"
OUT     <- file.path(ANA_DIR, "ORTAM"); dir.create(OUT, showWarnings = FALSE)
t0 <- Sys.time()
alan <- fread(file.path(ANA_DIR, "HAZIR", "alan_meta.csv"), encoding = "UTF-8")[, .(studyCode, lat, lon, elev_m)]
cat(sprintf("%d alan\n", nrow(alan)))
pts <- vect(alan, geom = c("lon", "lat"), crs = "EPSG:4326")

ara <- function(ad, ifade) {         # aşama sonucu varsa oku, yoksa hesapla ve kaydet
  f <- file.path(OUT, paste0("ara_", ad, ".rds"))
  if (file.exists(f)) { cat("  (kayıtlı sonuç kullanıldı:", ad, ")\n"); return(readRDS(f)) }
  x <- ifade(); saveRDS(x, f); x
}

# ---- 1. SoilGrids 2.0 (0–30 cm, kalınlık ağırlıklı ortalama) ------------------
cat("\n[1/4] SoilGrids toprak özellikleri (internetten okunuyor; 20–60 dk)...\n")
OZ <- c(sand = 10, clay = 10, soc = 10, phh2o = 10, bdod = 100, cfvo = 10, nitrogen = 100)   # birim bölenleri
DER <- c("0-5cm" = 5, "5-15cm" = 10, "15-30cm" = 15)
toprak <- ara("toprak", function() {
  out <- data.table(studyCode = alan$studyCode)
  for (v in names(OZ)) {
    acc <- 0; w <- 0
    for (dd in names(DER)) {
      url <- sprintf("/vsicurl/https://files.isric.org/soilgrids/latest/data_aggregated/1000m/%s/%s_%s_mean_1000.tif", v, v, dd)
      r <- tryCatch(rast(url), error = function(e) NULL)
      if (is.null(r)) { cat("   okunamadı:", v, dd, "\n"); next }
      p <- project(pts, crs(r))
      x <- extract(r, p, ID = FALSE)[[1]]
      bos <- which(is.na(x) | x == 0)
      if (length(bos)) {                 # su/kaya pikseline düşen noktalar: 2 km çevrenin ortalaması
        x2 <- extract(r, buffer(p[bos], 2000), fun = mean, na.rm = TRUE, ID = FALSE)[[1]]
        x[bos] <- ifelse(is.finite(x2) & x2 > 0, x2, NA)
      }
      ok <- !is.na(x); acc <- acc + ifelse(ok, x * DER[dd], 0); w <- w + ifelse(ok, DER[dd], 0)
      cat(sprintf("   %-9s %-8s tamam (%d NA)\n", v, dd, sum(!ok)))
    }
    out[[paste0("toprak_", v)]] <- ifelse(w > 0, acc / w / OZ[v], NA)
  }
  out
})
# Birimler: sand, clay, cfvo (%); soc, nitrogen (g/kg); phh2o (pH); bdod (g/cm3)
# Faydalı su kapasitesi: Saxton & Rawls (2006) pedotransfer (kum, kil, organik madde)
S <- toprak$toprak_sand / 100; C <- toprak$toprak_clay / 100; OM <- toprak$toprak_soc / 10 * 1.724
t15 <- -0.024*S + 0.487*C + 0.006*OM + 0.005*S*OM - 0.013*C*OM + 0.068*S*C + 0.031; th15 <- t15 + (0.14*t15 - 0.02)
t33 <- -0.251*S + 0.195*C + 0.011*OM + 0.006*S*OM - 0.027*C*OM + 0.452*S*C + 0.299; th33 <- t33 + (1.283*t33^2 - 0.374*t33 - 0.015)
toprak[, toprak_faydali_su := pmax(th33 - th15, 0)]

# ---- 2. Copernicus DEM GLO-90: ~1 km pencerede yükselti, eğim, kuzeylik, TPI --------
cat("\n[2/4] Copernicus DEM topoğrafya (internetten okunuyor; 30–90 dk)...\n")
karo_adi <- function(lat, lon) {
  la <- floor(lat); lo <- floor(lon)
  sprintf("Copernicus_DSM_COG_30_%s%02d_00_%s%03d_00_DEM", ifelse(la >= 0, "N", "S"), abs(la), ifelse(lo >= 0, "E", "W"), abs(lo))
}
alan[, karo := karo_adi(lat, lon)]
topo <- ara("topo", function() {
  res <- vector("list", nrow(alan)); karolar <- unique(alan$karo); say <- 0
  for (k in karolar) {
    say <- say + 1
    r <- tryCatch(rast(sprintf("/vsicurl/https://copernicus-dem-90m.s3.amazonaws.com/%s/%s.tif", k, k)), error = function(e) NULL)
    for (i in which(alan$karo == k)) {
      la <- alan$lat[i]; lo <- alan$lon[i]
      v <- data.table(studyCode = alan$studyCode[i], dem_yukselti = NA_real_, egim_derece = NA_real_,
                      kuzeylik = NA_real_, tpi_m = NA_real_)
      if (!is.null(r)) {
        dx <- 0.02 / cos(la * pi / 180); e <- ext(lo - dx, lo + dx, la - 0.02, la + 0.02)   # ~2x2 km pencere
        w <- tryCatch(crop(r, e), error = function(e) NULL)
        if (!is.null(w) && sum(!is.na(values(w))) > 10) {
          sl <- terrain(w, "slope", unit = "degrees"); as <- terrain(w, "aspect", unit = "radians")
          yakin <- buffer(vect(cbind(lo, la), crs = "EPSG:4326"), 1000)
          ort <- function(x) extract(x, yakin, fun = mean, na.rm = TRUE, ID = FALSE)[[1]]
          merkez <- extract(w, vect(cbind(lo, la), crs = "EPSG:4326"), ID = FALSE)[[1]]
          v$dem_yukselti <- ort(w); v$egim_derece <- ort(sl); v$kuzeylik <- ort(cos(as))
          v$tpi_m <- merkez - global(w, "mean", na.rm = TRUE)[[1]]      # + sırt, − vadi
        }
      }
      res[[i]] <- v
    }
    if (say %% 100 == 0) cat(sprintf("   %d / %d karo (%.0f dk)\n", say, length(karolar), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  }
  rbindlist(res)
})

# ---- 3. RESOLVE Ecoregions 2017 -------------------------------------------------
cat("\n[3/4] Ekolojik bölgeler (RESOLVE 2017)...\n")
eco_dir <- file.path(OUT, "Ecoregions2017")
if (!length(list.files(eco_dir, pattern = "\\.shp$", recursive = TRUE))) {
  zipf <- file.path(OUT, "Ecoregions2017.zip")
  if (!file.exists(zipf)) {
    options(timeout = 1800)
    ok <- tryCatch({ download.file("https://storage.googleapis.com/teow2016/Ecoregions2017.zip", zipf, mode = "wb"); TRUE },
                   error = function(e) FALSE)
    if (!ok) stop("Ecoregions2017.zip indirilemedi. https://ecoregions.appspot.com adresinden indirip ", OUT, " klasörüne koyun ve betiği yeniden çalıştırın.")
  }
  unzip(zipf, exdir = eco_dir)
}
eco <- ara("eko", function() {
  v <- vect(list.files(eco_dir, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE)[1])
  x <- extract(v, pts)                                        # nokta başına bir satır (çakışmada ilki)
  x <- x[!duplicated(x[[1]]), ]; x <- x[order(x[[1]]), c("ECO_ID", "ECO_NAME", "BIOME_NUM", "BIOME_NAME", "REALM")]
  bos <- which(is.na(x$ECO_ID) | x$ECO_ID == 0)              # kıyı/göl kenarı: en yakın poligon
  if (length(bos)) { nn <- nearest(pts[bos], v); x[bos, ] <- as.data.frame(v[nn$to_id, c("ECO_ID", "ECO_NAME", "BIOME_NUM", "BIOME_NAME", "REALM")]) }
  data.table(studyCode = alan$studyCode, eko_id = x$ECO_ID, eko_ad = x$ECO_NAME, biyom_no = x$BIOME_NUM, biyom_ad = x$BIOME_NAME, alem = x$REALM)
})

# ---- 4. Köppen–Geiger (Beck ve ark. 2023), 1931–1960 dönemi, 0,01° --------------
cat("\n[4/4] Köppen–Geiger iklim tipi...\n")
kg_dir <- file.path(OUT, "koppen")
if (!length(list.files(kg_dir, pattern = "\\.tif$", recursive = TRUE))) {
  zipf <- file.path(OUT, "koppen_geiger_tif.zip")
  if (!file.exists(zipf)) stop("koppen_geiger_tif.zip bulunamadı. https://figshare.com/articles/dataset/21789074 adresinden indirip ", OUT, " klasörüne koyun.")
  unzip(zipf, exdir = kg_dir)
}
kg <- ara("koppen", function() {
  tifs <- list.files(kg_dir, pattern = "0p00833333\\.tif$|0p01\\.tif$", recursive = TRUE, full.names = TRUE)   # ~1 km sürüm
  f <- tifs[grepl("1931_1960", tifs)][1]; if (is.na(f)) f <- tifs[grepl("1901_1930", tifs)][1]; if (is.na(f)) f <- tifs[1]
  cat("   kullanılan dosya:", f, "\n")
  x <- extract(rast(f), pts, ID = FALSE)[[1]]
  bos <- which(is.na(x) | x == 0)
  if (length(bos)) x[bos] <- extract(rast(f), buffer(pts[bos], 3000), fun = function(z) { z <- z[z > 0 & !is.na(z)]; if (length(z)) as.numeric(names(which.max(table(z)))) else NA }, ID = FALSE)[[1]]
  kod <- c("Af","Am","Aw","BWh","BWk","BSh","BSk","Csa","Csb","Csc","Cwa","Cwb","Cwc","Cfa","Cfb","Cfc",
           "Dsa","Dsb","Dsc","Dsd","Dwa","Dwb","Dwc","Dwd","Dfa","Dfb","Dfc","Dfd","ET","EF")
  data.table(studyCode = alan$studyCode, koppen_no = x, koppen = kod[x], koppen_dosya = basename(dirname(f)))
})

# ---- 5. Birleştir ve yaz ---------------------------------------------------------
sonuc <- Reduce(function(a, b) merge(a, b, by = "studyCode", all.x = TRUE), list(alan[, .(studyCode, lat, lon, elev_m)], toprak, topo, eco, kg))
fwrite(sonuc, file.path(OUT, "alan_ortam.csv"))
writeLines(c(paste("Erişim tarihi:", format(Sys.Date())),
  "SoilGrids 2.0, 1 km toplulaştırılmış (Poggio ve ark. 2021, SOIL 7:217–240), ISRIC, CC BY 4.0",
  "Copernicus DEM GLO-90 (ESA/Copernicus), AWS açık veri; © DLR e.V. 2010–2014 ve © Airbus Defence and Space GmbH 2014–2018, Copernicus programı kapsamında sağlanmıştır",
  "RESOLVE Ecoregions 2017 (Dinerstein ve ark. 2017, BioScience 67:534–545), CC BY 4.0",
  "Köppen–Geiger 1 km, 1931–1960 (Beck ve ark. 2023, Scientific Data 10:724), figshare doi:10.6084/m9.figshare.21789074, CC BY 4.0",
  "Faydalı su kapasitesi: Saxton & Rawls (2006) pedotransfer fonksiyonu"), file.path(OUT, "kaynaklar_ve_lisanslar.txt"))

cat("\n==== YETİŞME ORTAMI AKTARIMI TAMAM ====\n")
cat("Alan:", nrow(sonuc), "\n")
for (v in grep("^toprak_|^dem_|^egim|^kuzeylik|^tpi|^eko_id|^biyom_no|^koppen_no", names(sonuc), value = TRUE))
  cat(sprintf("  %-20s eksik: %4d   medyan: %s\n", v, sum(is.na(sonuc[[v]])), format(signif(median(sonuc[[v]], na.rm = TRUE), 3))))
cat("Biyom sayısı:", uniqueN(sonuc$biyom_no), " Ekolojik bölge:", uniqueN(sonuc$eko_id), " Köppen tipi:", uniqueN(sonuc$koppen), "\n")
cat("Süre:", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "dk\n")
