# Growth theory changes projected tree-growth responses to climate despite similar historical skill

Code, trained-model outputs and site-level results for:

> Ercanlı, İ. *Growth theory changes projected tree-growth responses to climate despite similar historical skill.* Manuscript under review.

**Interactive map of the projections:** https://ilkerercanli.github.io/growth-theory-ai/

## What the study does

A Richards-type size-dependent growth potential and Liebig-type, monotone limitation by temperature and moisture are embedded as hard constraints in a differentiable model of annual radial growth. A neural network predicts their site-specific parameters. The model (T+S) is compared with:

- an unconstrained network of equal capacity (U+S)
- gradient-boosted trees (XGBoost)
- a linear mixed-effects model (LMM)

The comparison uses 19.5 million annual rings from 120,332 trees at 6,280 sites of the International Tree-Ring Data Bank (ITRDB), with CRU TS 4.09 climate, and covers:

- distribution-shift tests
- an independent spatial-block benchmark of climate sensitivity
- climate perturbations
- CMIP6 projections (5 climate models × SSP1-2.6, SSP2-4.5 and SSP5-8.5)

## Repository layout

| Folder | Contents |
|---|---|
| `R/` | Data retrieval and preparation (run in this order) |
| `notebooks/` | Model training, evaluation and projections (Google Colab, T4 GPU; run in numerical order) |
| `python/` | Helper script for CMIP6 sea-cell correction |
| `data/` | Site list (`sites.csv`, ITRDB study codes and site index used by all models) and site environment variables (`site_environment.csv`) |
| `results/` | All analysis outputs used in the manuscript (see `results/README.md`) |
| `figures/` | Script that draws the manuscript figures from `results/` |
| `preregistration/` | Dated internal analysis plan and dated prediction document for the acclimation test (21 October 2026), unchanged |
| `docs/` | Interactive web application (GitHub Pages) |

Comments and variable names in the scripts and notebooks are partly in Turkish; the tables below give the English meaning of each step.

### Pipeline

| Step | File | What it does |
|---|---|---|
| 1 | `R/01_itrdb_inventory.R` | Lists raw ring-width (.rwl) files of the ITRDB through the NOAA WDS-Paleo search API and checks usage notes |
| 2 | `R/02_cru_climate_extraction.R` | Extracts monthly CRU TS 4.09 temperature, precipitation, PET and vapour pressure for each site |
| 3 | `R/03_site_environment.R` | Soil (SoilGrids 2.0), topography (Copernicus DEM GLO-90), ecoregion (RESOLVE 2017) and Köppen–Geiger class per site |
| 4 | `R/04_prepare_ring_data.R` | Reads total ring width with dplR, builds series and site tables and test groups |
| 5 | `notebooks/01_data_tensors.ipynb` | VS-Lite soil moisture, day length, test splits and model tensors |
| 6 | `notebooks/02_model_training.ipynb` | Theory-constrained and unconstrained networks; training queue over tests and seeds |
| 7 | `notebooks/03_evaluation.ipynb` | Accuracy, equivalence tests, novelty, ablations, size exponent, Shapley values |
| 8 | `notebooks/04_exploratory_acclimation.ipynb` | Exploratory model with site-specific moisture-threshold adjustment |
| 9 | `notebooks/05_prespecified_tests.ipynb` | Pre-specified tests P1–P3 of the acclimation model |
| 10 | `notebooks/06_conventional_models_and_perturbations.ipynb` | XGBoost, LMM, species-calibrated process model; climate-perturbation responses; synthetic recovery of *m* |
| 11 | `notebooks/07_robustness_checks.ipynb` | Tuned XGBoost, seeded equivalence, starting-value robustness, dry-region analyses |
| 12 | `notebooks/08_final_models_and_CMIP6_projections.ipynb` | Final models on all data (5 seeds) and CMIP6 projections at fixed size and free-running |
| 13 | `notebooks/09_independent_benchmark_and_uncertainty.ipynb` | Spatial-block benchmark of climate sensitivity, aggregated R², projection uncertainty, *B*max check |
| 14 | `notebooks/10_final_checks_vpd_powerlaw_warming.ipynb` | VPD-limited model (T_D+S), power-law potential, causes of divergence, residuals under recent warming |

## Data and licences

No data requiring access permission were used. Raw input data are **not redistributed** here. They are retrieved from their sources by the scripts:

| Data | Source | Licence |
|---|---|---|
| ITRDB raw ring widths | NOAA World Data Service for Paleoclimatology (accessed 19 October 2026); study codes in `data/sites.csv` | Public; cite the original contributors |
| CRU TS 4.09 | Centre for Environmental Data Analysis | Open Government Licence v3 |
| CMIP6 (GFDL-ESM4, IPSL-CM6A-LR, MPI-ESM1-2-HR, MRI-ESM2-0, UKESM1-0-LL) | Google Cloud public CMIP6 archive / ESGF | CC BY 4.0 |
| SoilGrids 2.0 | ISRIC | CC BY 4.0 |
| Copernicus DEM GLO-90 | ESA / Copernicus | Copernicus DEM licence |
| RESOLVE Ecoregions 2017 | Dinerstein et al. 2017 | CC BY 4.0 |
| Köppen–Geiger 1 km | Beck et al. 2023 | CC BY 4.0 |

## Software

Python 3.13, PyTorch 2.11 (CUDA 13.0), XGBoost 3.4.1, NumPy 2.1.3, pandas 2.2.3, SciPy 1.16.3, xarray 2025.12.0, zarr 3.4.1, gcsfs 2025.12.0 (see `requirements.txt`). R ≥ 4.3 with dplR, data.table, arrow, jsonlite, ncdf4, R.utils and terra.

## Licence

Code: MIT licence (`LICENSE`). Results, site tables and documents: CC BY 4.0.

## Citation

Please cite the article (when published) and this repository (see `CITATION.cff`).

## Use of AI tools

A large language model (Claude, Anthropic) assisted with code development and language editing. The author designed the study, checked all code and results and takes full responsibility for the content.
