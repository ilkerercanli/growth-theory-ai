# =============================================================================
# ITRDB ENVANTERİ — ham halka genişliği (.rwl) dosyaları
# Amaç: Teori gömülü yapay zekâ çalışması için hangi tür/cinste kaç alan,
#       kaç ağaç (seri), hangi yıl aralığı ve hangi kullanım notu var?
#
# Kaynak: NOAA NCEI World Data Service for Paleoclimatology arama API'si
#   https://www.ncei.noaa.gov/access/paleo-search/study/search.json
#
# Çıktılar (OUT_DIR içinde):
#   1_itrdb_dosyalar.csv        : her ham .rwl dosyası için meta veri + lisans notu
#   2_itrdb_tur_ozeti.csv       : tür bazında alan sayıları ve kapsam
#   3_itrdb_cins_ozeti.csv      : cins bazında özet (taksonomik test tasarımı için)
#   4_itrdb_seri_ozeti.csv      : (ADIM 3 çalıştırılırsa) her alanda seri sayısı,
#                                 seri uzunluğu, 1960 öncesi/sonrası kapsam
#   5_lisans_kontrol.csv        : kısıt içerebilecek kullanım notu bulunan kayıtlar
#
# Gerekli paketler: jsonlite (zorunlu), dplR (yalnızca ADIM 3 için)
#   install.packages(c("jsonlite", "dplR"))
#
# Prof. Dr. İlker Ercanlı — taslak betik, Ekim 2026
# =============================================================================

# ---- Paketler (eksikse otomatik kurulur) -------------------------------------
for (pk in c("jsonlite", "dplR")) {
  if (!requireNamespace(pk, quietly = TRUE)) install.packages(pk, repos = "https://cloud.r-project.org")
}
library(jsonlite)

# ---- Ayarlar ----------------------------------------------------------------
# Çıktı klasörü tam yol olarak verildi; çalışma dizini ne olursa olsun aynı yere yazar.
OUT_DIR        <- "C:/Users/ercan/Desktop/ITRDB_envanter"
CRU_BASLANGIC  <- 1901                    # CRU TS başlangıç yılı
MIN_ORTAK_YIL  <- 50                      # CRU ile en az kaç yıl örtüşme istenir
BOLME_YILI     <- 1960                    # zamansal test için eğitim/test sınırı
SERI_INDIR     <- TRUE                    # TRUE: .rwl dosyalarını indirip seri say (saatler sürer)
SERI_INDIR_TUR <- NULL                    # ör. c("PISY","PSME"); NULL = tüm uygun alanlar
# Analizden çıkarılan alanlar (gerekçe: Methods, "Tree-ring data")
#   CO700-CO702: koordinatlar katkıda bulunanlarca gizlenmiş -> iklim eşlenemez
#   WY054, WY055: üçüncü taraf izniyle gönderilmiş -> ihtiyaten çıkarıldı
HARIC_ALANLAR  <- c("CO700", "CO701", "CO702", "WY054", "WY055")

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
API <- "https://www.ncei.noaa.gov/access/paleo-search/study/search.json"

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a
chr <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else as.character(x[[1]])
num <- function(x) suppressWarnings(as.numeric(chr(x)))

# ---- ADIM 1: API'den tüm ITRDB çalışmalarını çek ------------------------------
# dataTypeId = 18 -> TREE RING; dataPublisher = NOAA; metinde "ITRDB" geçenler
# Sayfalama "skip" parametresiyle yapılır. Sunucu zaman zaman yavaş yanıt
# verdiği için: zaman aşımı 300 sn, her sayfa için 5 deneme, kaldığı yerden devam.
options(timeout = 300)
RDS <- file.path(OUT_DIR, "itrdb_api_ham.rds")

sayfa_getir <- function(skip, limit, deneme = 5) {
  url <- paste0(API, "?dataPublisher=NOAA&dataTypeId=18&searchText=ITRDB",
                "&limit=", limit, "&skip=", skip)
  for (k in seq_len(deneme)) {
    js <- tryCatch(fromJSON(url, simplifyVector = FALSE), error = function(e) {
      message(sprintf("  Deneme %d başarısız: %s", k, conditionMessage(e))); NULL })
    if (!is.null(js)) return(js)
    Sys.sleep(10 * k)   # her başarısız denemede biraz daha bekle
  }
  stop(sprintf("skip=%d sayfası %d denemede alınamadı. Betiği yeniden çalıştırın; kaldığı yerden devam eder.", skip, deneme))
}

api_cek <- function(limit = 100, bekle = 1) {
  tum <- if (file.exists(RDS)) readRDS(RDS) else list()   # önceki indirmeden devam
  skip <- length(tum)
  if (skip > 0) message(sprintf("Önceki indirmede %d çalışma bulundu; skip=%d'den devam ediliyor.", skip, skip))
  repeat {
    message(sprintf("skip=%d indiriliyor...", skip))
    js <- sayfa_getir(skip, limit)
    yeni <- js$study %||% list()
    if (length(yeni) == 0) break
    tum <- c(tum, yeni)
    saveRDS(tum, RDS)                # her sayfadan sonra kaydet
    skip <- skip + length(yeni)
    if (length(yeni) < limit) break  # son sayfa
    Sys.sleep(bekle)                 # sunucuya nazik davran
  }
  ids <- vapply(tum, function(s) chr(s$NOAAStudyId), "")
  tum <- tum[!duplicated(ids)]
  message(sprintf("Toplam %d farklı çalışma alındı.", length(tum)))
  tum
}

# Önceki tam indirme diskte varsa API'ye hiç gidilmez (sunucu, kayıtların sonundan
# sonraki sayfa için boş yanıt döndürüyor). Yeniden indirmek için YENIDEN_CEK <- TRUE.
YENIDEN_CEK <- FALSE
if (file.exists(RDS) && !YENIDEN_CEK) {
  studies <- readRDS(RDS)
  studies <- studies[!duplicated(vapply(studies, function(s) chr(s$NOAAStudyId), ""))]
  message(sprintf("Diskteki kayıt kullanılıyor: %d çalışma (API'ye bağlanılmadı).", length(studies)))
} else {
  if (YENIDEN_CEK && file.exists(RDS)) file.remove(RDS)
  studies <- api_cek()
}

# ---- ADIM 2: Ham ölçüm (.rwl) dosyalarını tabloya dök -------------------------
kisit_kelime <- "(?i)restrict|permission|not for|non-?commercial|embargo|contact the|do not"

satirlar <- list()
for (s in studies) {
  for (site in s$site %||% list()) {
    koord <- site$geo$geometry$coordinates %||% list(NA, NA)   # [enlem, boylam]
    prop  <- site$geo$properties
    for (pd in site$paleoData %||% list()) {
      sp <- pd$species %||% list(list())
      for (f in pd$dataFile %||% list()) {
        aciklama <- chr(f$urlDescription)
        dosya    <- chr(f$fileUrl)
        # Yalnızca Tucson biçimli ham ölçüm dosyası (.rwl); NOAA şablon dosyası hariç
        if (is.na(aciklama) || aciklama != "Raw Measurements") next
        if (is.na(dosya) || !grepl("\\.rwl$", dosya, ignore.case = TRUE)) next
        degiskenler <- f$variables %||% list()
        ek_bilgi <- paste(vapply(degiskenler, function(v) { a <- chr(v$cvAdditionalInfo); if (is.na(a)) "" else a }, ""),
                          collapse = " | ")
        notlar <- paste(na.omit(c(chr(s$studyNotes), chr(pd$dataTableNotes),
                                  chr(s$contactInfo$constraints))), collapse = " | ")
        satirlar[[length(satirlar) + 1]] <- data.frame(
          studyCode   = chr(s$studyCode),
          studyName   = chr(s$studyName),
          NOAAStudyId = chr(s$NOAAStudyId),
          doi         = chr(s$doi),
          investigators = chr(s$investigators),
          siteName    = chr(site$siteName),
          locationName= chr(site$locationName),
          lat         = num(koord[1]),
          lon         = num(koord[2]),
          elev_m      = num(prop$minElevationMeters),
          speciesCode = chr(sp[[1]]$speciesCode),
          scientificName = chr(sp[[1]]$scientificName),
          firstYearCE = num(pd$earliestYearCE),
          lastYearCE  = num(pd$mostRecentYearCE),
          rwl_url     = dosya,
          license_desc= chr(s$dataLicenseDescription),
          license_url = chr(s$dataLicenseUrl),
          notes       = substr(notlar, 1, 1000),
          pith_mention= grepl("(?i)pith", paste(ek_bilgi, notlar), perl = TRUE),
          kisit_supheli = grepl(kisit_kelime, paste(chr(s$dataLicenseDescription), notlar), perl = TRUE),
          stringsAsFactors = FALSE)
      }
    }
  }
}
dosyalar <- do.call(rbind, satirlar)

# Türetilmiş alanlar
dosyalar$genus      <- sub(" .*", "", dosyalar$scientificName)
dosyalar$continent  <- sub("^Continent>([^>]+).*", "\\1", dosyalar$locationName)
dosyalar$cru_ortak  <- pmax(0, dosyalar$lastYearCE - pmax(dosyalar$firstYearCE, CRU_BASLANGIC) + 1)
dosyalar$cru_uygun  <- dosyalar$cru_ortak >= MIN_ORTAK_YIL
dosyalar$bolme_kapsar <- dosyalar$firstYearCE <= (BOLME_YILI - 30) & dosyalar$lastYearCE >= (BOLME_YILI + 30)
dosyalar <- dosyalar[!duplicated(dosyalar$rwl_url), ]
dosyalar$haric <- dosyalar$studyCode %in% HARIC_ALANLAR   # analiz dışı alanlar işaretlenir

write.csv(dosyalar, file.path(OUT_DIR, "1_itrdb_dosyalar.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# Lisans / kullanım notu kontrolü: şüpheli kayıtlar ayrı dosyada, elle bakılmalı
write.csv(dosyalar[dosyalar$kisit_supheli | !is.na(dosyalar$license_desc), ],
          file.path(OUT_DIR, "5_lisans_kontrol.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# ---- Özet tabloları -----------------------------------------------------------
ozet <- function(df, grup) {
  g <- split(df, df[[grup]])
  out <- do.call(rbind, lapply(names(g), function(k) {
    x <- g[[k]]
    data.frame(grup = k,
               n_alan            = length(unique(x$studyCode)),
               n_alan_cru_uygun  = length(unique(x$studyCode[x$cru_uygun])),
               n_alan_1960_kapsar= length(unique(x$studyCode[x$bolme_kapsar])),
               n_kita            = length(unique(x$continent)),
               kitalar           = paste(sort(unique(x$continent)), collapse = "; "),
               n_pith_notu       = sum(x$pith_mention),
               n_kisit_supheli   = sum(x$kisit_supheli),
               enlem_aralik      = sprintf("%.1f to %.1f", min(x$lat, na.rm = TRUE), max(x$lat, na.rm = TRUE)),
               stringsAsFactors = FALSE)
  }))
  names(out)[1] <- grup
  out[order(-out$n_alan_cru_uygun), ]
}

tur_ozet  <- ozet(dosyalar, "scientificName")
cins_ozet <- ozet(dosyalar, "genus")
write.csv(tur_ozet,  file.path(OUT_DIR, "2_itrdb_tur_ozeti.csv"),  row.names = FALSE, fileEncoding = "UTF-8")
write.csv(cins_ozet, file.path(OUT_DIR, "3_itrdb_cins_ozeti.csv"), row.names = FALSE, fileEncoding = "UTF-8")

cat("\n==== GENEL ====\n")
cat("Ham .rwl dosyası      :", nrow(dosyalar), "\n")
cat("Farklı alan           :", length(unique(dosyalar$studyCode)), "\n")
cat("CRU ile >=", MIN_ORTAK_YIL, "yıl örtüşen alan:", length(unique(dosyalar$studyCode[dosyalar$cru_uygun])), "\n")
cat("1960 bölmesini kapsayan alan:", length(unique(dosyalar$studyCode[dosyalar$bolme_kapsar])), "\n")
cat("Tür / cins sayısı     :", length(unique(dosyalar$scientificName)), "/", length(unique(dosyalar$genus)), "\n")
cat("Lisans/kısıt şüphesi  :", sum(dosyalar$kisit_supheli), "dosya (5_lisans_kontrol.csv'ye bakın)\n")
cat("\n==== EN ÇOK ALANI OLAN 15 CİNS ====\n")
print(head(cins_ozet[, c("genus","n_alan","n_alan_cru_uygun","n_alan_1960_kapsar","n_kita")], 15), row.names = FALSE)

# ---- ADIM 3 (isteğe bağlı): .rwl dosyalarını indirip ağaç/seri say -------------
# SERI_INDIR <- TRUE yapın. Tüm arşiv için saatler sürebilir; önce birkaç türle deneyin.
if (SERI_INDIR) {
  library(dplR)
  hedef <- dosyalar[dosyalar$cru_uygun & !dosyalar$haric, ]
  if (!is.null(SERI_INDIR_TUR)) hedef <- hedef[hedef$speciesCode %in% SERI_INDIR_TUR, ]
  rwl_dir <- file.path(OUT_DIR, "RWL"); dir.create(rwl_dir, showWarnings = FALSE)
  # Aynı ada sahip dosyaların çakışmaması için yerel ad: çalışma kimliği + dosya adı
  hedef$yerel <- file.path(rwl_dir, paste0(hedef$NOAAStudyId, "_", basename(hedef$rwl_url)))

  bos_sonuc <- function(u, durum) data.frame(rwl_url = u, durum = durum,
    n_seri = NA, n_agac_tahmini = NA, medyan_uzunluk = NA, n_seri_50yil = NA,
    n_seri_1960_kapsar = NA, n_seri_cru_50 = NA, ilk_yil = NA, son_yil = NA)

  indir <- function(u, yerel, deneme = 3) {
    for (k in seq_len(deneme)) {
      ok <- tryCatch({ download.file(u, yerel, mode = "wb", quiet = TRUE); TRUE },
                     error = function(e) FALSE, warning = function(w) FALSE)
      if (ok && file.exists(yerel) && file.info(yerel)$size > 0) return(TRUE)
      if (file.exists(yerel)) file.remove(yerel)   # yarım dosyayı sil
      Sys.sleep(5 * k)
    }
    FALSE
  }

  n <- nrow(hedef); sonuc <- vector("list", n); t0 <- Sys.time()
  message(sprintf("ADIM 3: %d dosya işlenecek. İlerleme her 100 dosyada bir yazılır.", n))
  for (i in seq_len(n)) {
    u <- hedef$rwl_url[i]; yerel <- hedef$yerel[i]
    if (!file.exists(yerel) && !indir(u, yerel)) { sonuc[[i]] <- bos_sonuc(u, "indirilemedi"); next }
    # read.rwl her dosya için seri tablosunu konsola basar; capture.output ile susturulur
    rw <- tryCatch({
      invisible(capture.output(x <- suppressWarnings(suppressMessages(read.rwl(yerel, format = "tucson")))))
      x
    }, error = function(e) NULL)
    if (is.null(rw) || ncol(rw) == 0) { sonuc[[i]] <- bos_sonuc(u, "okunamadi"); next }
    yil <- as.numeric(rownames(rw))
    uz  <- colSums(!is.na(rw))
    bas <- apply(rw, 2, function(z) min(yil[!is.na(z)]))
    son <- apply(rw, 2, function(z) max(yil[!is.na(z)]))
    sonuc[[i]] <- data.frame(rwl_url = u, durum = "tamam",
      n_seri             = ncol(rw),
      n_agac_tahmini     = length(unique(substr(colnames(rw), 1, nchar(colnames(rw)) - 1))),
      medyan_uzunluk     = median(uz),
      n_seri_50yil       = sum(uz >= 50),
      n_seri_1960_kapsar = sum(bas <= BOLME_YILI - 30 & son >= BOLME_YILI + 30),
      n_seri_cru_50      = sum(pmax(0, son - pmax(bas, CRU_BASLANGIC) + 1) >= MIN_ORTAK_YIL),
      ilk_yil = min(yil), son_yil = max(yil))
    if (i %% 100 == 0 || i == n) {
      gecen <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
      message(sprintf("%d / %d dosya (%.0f dk geçti, tahmini kalan %.0f dk)", i, n, gecen, gecen / i * (n - i)))
      # Ara kayıt: bilgisayar kapanırsa en azından buraya kadarki özet kalsın
      ara <- do.call(rbind, sonuc[!vapply(sonuc, is.null, TRUE)])
      write.csv(ara, file.path(OUT_DIR, "4_itrdb_seri_ozeti_ARA.csv"), row.names = FALSE, fileEncoding = "UTF-8")
    }
  }
  seri_ozet <- do.call(rbind, sonuc)
  seri_ozet <- merge(hedef[, c("studyCode","NOAAStudyId","scientificName","genus","continent","lat","lon","rwl_url")],
                     seri_ozet, by = "rwl_url")
  write.csv(seri_ozet, file.path(OUT_DIR, "4_itrdb_seri_ozeti.csv"), row.names = FALSE, fileEncoding = "UTF-8")
  cat("\n==== SERİ ÖZETİ ====\n")
  print(table(seri_ozet$durum))
  ok <- seri_ozet$durum == "tamam"
  cat("Toplam seri           :", sum(seri_ozet$n_seri[ok]), "\n")
  cat("Tahmini ağaç sayısı   :", sum(seri_ozet$n_agac_tahmini[ok]), "\n")
  cat("CRU ile >=50 yıl seri :", sum(seri_ozet$n_seri_cru_50[ok]), "\n")
  cat("1960'ı kapsayan seri  :", sum(seri_ozet$n_seri_1960_kapsar[ok]), "\n")
}

# NOTLAR
# - n_agac_tahmini: ITRDB seri kodlarında son karakter genellikle karot harfidir
#   (ör. ABC01A, ABC01B -> aynı ağaç). Bu bir YAKLAŞIMDIR; kodlama alanlar arasında değişir.
# - pith_mention: yalnızca meta veride "pith" geçip geçmediğini gösterir. Tucson .rwl
#   biçimi öze uzaklık bilgisini içermez; yaş/boyut alt kümesi için ayrı kontrol gerekir.
# - kisit_supheli: kullanım notunda kısıt çağrıştıran kelime var demektir; kayıt
#   elle okunmalı. Kısıt doğrulanırsa kayıt analiz dışında bırakılmalı.
# - Ham ITRDB verisini yeniden yayımlamayın; veri erişilebilirlik bölümünde
#   studyCode ve DOI listesini verin (NOAA: ABD dışı veriler ticari amaçla yeniden
#   dağıtılamaz; akademik kullanım serbesttir, atıf istenir).
