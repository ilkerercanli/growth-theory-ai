# Results

All outputs used in the manuscript, as written by the notebooks. File names are in Turkish; this table gives their content. Model labels inside the files: `teori` = theory-constrained (T), `serbest` = unconstrained (U), `_ortam` = with site variables (+S), `teori_vpd` = with atmospheric drought (T_D), `uyum` = exploratory acclimation, `xgb` = gradient-boosted trees, `dkm`/`Karma model` = linear mixed model. Test labels: `zaman` temporal, `takson` unseen genera, `bolge-*` withheld region, `iklim-sicak` warmest 10%, `iklim-kurak` driest 10%, `blok-*` spatial-block fold. `sabit`/`guncel` = site normals fixed/updated.

| File | Content | Manuscript |
|---|---|---|
| T1_ana_tablo.csv, T1b_duyarlilik.csv | RMSE, NLL and interval coverage of all networks in all tests; sensitivity | Extended Data Table 1 |
| T2_yenilik_dilimleri.csv, T3_hata_yenilik_egimi.csv, E4_yenilik_normaller.csv | Error by climatic novelty; error–novelty slopes (two novelty definitions) | Supplementary Table 3 |
| T4_ablasyon.csv, D4_ablasyon_5tohum.csv | Ablations (one seed; five seeds) | Supplementary Table 2 |
| T5_metabolik_us_m.csv, T8_m_profil.csv, E3_sentetik_m.csv, E3b_sentetik_m_ozet.json, G5_m_saglamlik.csv | Size exponent: genus medians, likelihood profile, synthetic recovery, starting-value robustness | Extended Data Fig. 2; Supplementary Table 12 |
| T7_serbest_gidis.csv | Free-running growth in the test period | Supplementary Information |
| T9_teori_ihlal.csv | Growth-law violations of the networks | Fig. 3 |
| T10_shap_grup.csv, T11_shap_parametre.csv, Sekil6_shap.png | Group Shapley values | Extended Data Fig. 3 |
| T12_kurak_teshis.csv, G6_kurak_bolge.csv | Dry-site diagnostics; dry sites outside North America | Supplementary Tables 5, 11 |
| T13_ortam_etkisi.csv | Effect of site variables | Supplementary Information |
| T14_hata_varyans_ayristirma.csv, T15_kronoloji_korelasyonu.csv, T16_kalibre_R2.csv | Variance partition, chronology correlation, calibrated R² | Supplementary Table 4 |
| D1_dogrulayici_testler.csv, D2_ongoru_kararlari.csv, K1_yerel_uyum.csv, K2_yerel_uyum_ihlal.csv, K3_yerel_uyum_teshis.csv | Pre-specified tests P1–P3 and decision for the acclimation model | Extended Data Table 3 |
| D3_esdegerlik_TOST.csv, G3_tohumlu_esdegerlik.csv | Equivalence tests (TOST), with ensemble-member resampling | Fig. 2; Supplementary Table 1 |
| D5_fiziksel_senaryo.csv, E1_fiziksel_senaryo_topluluk.csv, E1b_fiziksel_senaryo_tohum_ort_ss.csv | Responses to +20% precipitation and +1 °C | Fig. 3; Extended Data Table 2; Supplementary Table 6 |
| E2_klasik_karsilastirma.csv, G4_xgb_ayar_arama.csv, G4_xgb_ayarli.csv | Conventional models; XGBoost tuning | Extended Data Fig. 1; Extended Data Table 1 |
| G1_senaryo_tum_modeller.csv, G2_ampirik_yon_uyumu.csv, G2b_gozlenen_alan_duyarliligi.csv | Earlier benchmark at training sites | Supplementary Table 15 |
| H0_cmip6_modeller.csv, H0_surumler.json | CMIP6 models and members; software versions | Methods |
| H1_sabit_boyut_agac.npz | Projected change (log ratio) for 12,000 sampled trees, by climate model, scenario, period, normals and model | Fig. 5 |
| H1_yenilik_alan.npz | Climatic novelty of future normals per site | Fig. 5 |
| H1_sabit_boyut_ozet.csv, H2_sabit_boyut_gcm_ortalama.csv | Projection summaries by climate model and averaged over climate models | Fig. 5; Extended Data Table 5 |
| H3_model_anlasmazligi.csv | Sign disagreement between models across sites | Supplementary Table 13 |
| H4_harita_ssp585_2071.csv | Site-level projected change (log ratio), SSP5-8.5, 2071–2100, normals fixed; row index = `site_idx` in `data/sites.csv` | Fig. 5c,d |
| H5_serbest_yurutme_ozet.csv | Free-running growth 2025–2100 | Supplementary Table 14 |
| I1_bagimsiz_duyarlilik.csv, I1b_bagimsiz_duyarlilik_farklar.csv, I1c_alan_duyarliliklari.csv, I1d_blok_dogruluk.csv | Independent spatial-block benchmark: metrics, model differences, site coefficients (`s` = `site_idx`; `_g` observed), block accuracy | Fig. 4; Extended Data Table 4 |
| I2_senaryo_guven_araliklari.csv, I4_projeksiyon_belirsizlik.csv, I4c_yagis_orani_siniri.csv | Uncertainty of perturbation responses and projections | Fig. 3, 5 |
| I3_toplanmis_R2.csv | Explained variance at aggregation levels | Extended Data Table 6 |
| I5_Bmax_kontrol.csv | Size scale *B*max check | Supplementary Table 16 |
| J0_kuvvet_potansiyel_zamansal.csv, J1_projeksiyon_vpd_kuvvet.csv | Power-law potential; projections of T_D+S and power-law model | Extended Data Table 5 |
| J2_ayrisma_iklim_yeniligi.csv, J2b_ayrisma_zT_dilim.csv | Divergence versus climatic novelty (*z*_T) | Supplementary Table 19 |
| J3_zamansal_artik_isinma.csv, J3b_onyil_artik.csv | Residuals versus temperature anomaly and by decade | Supplementary Table 20 |
| K1_dengeli_dogruluk.csv, K2_guc_analizi.csv | Balanced accuracy and power analysis of the benchmark | Supplementary Table 18 |
| Sekil2_yenilik.png, Sekil5_m_profil.png | Working figures | – |
