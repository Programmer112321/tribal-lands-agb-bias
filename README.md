# Local-scale bias in global forest aboveground biomass products on Tribal lands

Code for: Chu, D., et al. *Local-scale bias in global products of forest aboveground biomass related to
structural diversity and stand density.* Remote Sensing of Environment (under review, RSE-D-26-03577).

The analysis compares two global aboveground biomass (AGB) products, GEDI L4B v2.1 (1 km) and ESA CCI Biomass
v6.0 (2020, 100 m), with a reference AGB built from USDA Forest Service Forest Inventory and Analysis (FIA)
plots in 257 FIA hexagons on 20 Tribal lands in the conterminous United States. It then explains the bias with
ten forest and site factors (XGBoost + SHAP) and tests bias-correction models.

## Layout and run order

Run every script from the repository root, in the order listed. R scripts: `Rscript <folder>/<script>.R`;
Python scripts: `python <folder>/<script>.py`. Outputs go to `output/<stage>/` (not tracked by git).

| Stage | Script | What it does | Paper |
|---|---|---|---|
| 01 study area | `01_study_area/01_fia_plot_agb.R` | Plot-level forest AGB from FIA (rFIA), 2018–2023 | 2.3 |
| | `01_study_area/02_hexagon_province_pieces.R` | FIA hexagons split by USFS ecological province | 2.3 |
| | `01_study_area/03_tribal_land_pieces.R` | Tribal lands × hexagons; overlap and forest area | 2.1 |
| | `01_study_area/04_select_hexagons.R` | Study hexagons (259 on 20 Tribal lands) | 2.1 |
| 02 reference | `02_reference/01_fia_canopy_intervals.R` | FIA plot AGB by canopy cover; canopy-cover intervals per hexagon piece | 2.3 |
| | `02_reference/02_products_and_reference.R` | Forest mask; satellite AGB and product-matched reference per hexagon | 2.1, 2.3 |
| | `02_reference/03_forest_area_reference.R` | Product-independent reference (map in Fig. 1) | Fig. 1 |
| 03 predictors | `03_predictors/01_terrain.R` | Elevation, slope, northness (ASTER GDEM) | 2.4 |
| | `03_predictors/02_raster_predictors.R` | Canopy height, stand density, wood density, structural diversity, AWC, soil moisture; layers for the sensitivity analyses | 2.4 |
| | `03_predictors/03_treemap_stand_age.R` | Forest age from TreeMap 2020 | 2.4 |
| | `03_predictors/04_analysis_tables.R` | Analysis tables (bias, reference, predictors) and study regions | 2.1, 2.5 |
| 04 models | `04_models/01_bias_model.py` | Bias model (XGBoost), out-of-fold SHAP, response curves | 2.5.1, 3.2 |
| | `04_models/02_regional_correction.py` | Regional correction models | 2.5.2, 3.4 |
| | `04_models/03_global_correction.py` | Global correction model | 2.5.2, 3.4 |
| 05 sensitivity | `05_sensitivity/01_forest_loss.R` | Forest loss 2019–2023 per hexagon | 2.3 |
| | `05_sensitivity/02_scale.py` | Accuracy at hexagon, tribal-land and well-sampled level | Table S2 |
| | `05_sensitivity/03_period_summary.py` | FIA 2019–2023 / CCI 2021 runs compared with the main run | 2.3, 3.2 |
| 06 figures, tables | `06_figures_tables/fig1_study_area.R` | Fig. 1 | |
| | `06_figures_tables/fig2_accuracy_and_bias.R` | Fig. 2, Fig. S2 | |
| | `06_figures_tables/fig3_shap_and_response.R` | Fig. 3 | |
| | `06_figures_tables/figS3_response_curves.py` | Fig. S3 | |
| | `06_figures_tables/fig4_dominant_factor.R` | Fig. 4, Fig. S4 | |
| | `06_figures_tables/fig5_correction_performance.py` | Fig. 5, Fig. S5 | |
| | `06_figures_tables/figS1_tribal_land_accuracy.R` | Fig. S1 | |
| | `06_figures_tables/table_S1.py` | Table S1 | |
| | `06_figures_tables/manuscript_numbers.py` | Numbers quoted in the text | |

Stages 01–03 need the raw inputs (below); stage 04 onward needs only the stage-03 tables.

### Commands

```
Rscript 01_study_area/01_fia_plot_agb.R
Rscript 01_study_area/02_hexagon_province_pieces.R
Rscript 01_study_area/03_tribal_land_pieces.R
Rscript 01_study_area/04_select_hexagons.R
Rscript 02_reference/01_fia_canopy_intervals.R
Rscript 02_reference/02_products_and_reference.R
Rscript 02_reference/03_forest_area_reference.R
Rscript 03_predictors/01_terrain.R
Rscript 03_predictors/02_raster_predictors.R
Rscript 03_predictors/03_treemap_stand_age.R
Rscript 03_predictors/04_analysis_tables.R
python 04_models/01_bias_model.py
python 04_models/02_regional_correction.py
python 04_models/03_global_correction.py

# sensitivity: layers not imputed from FIA (Table S1)
python 04_models/01_bias_model.py output/03_predictors/analysis_main_nonfia.csv nonfia
python 04_models/02_regional_correction.py output/03_predictors/analysis_main_nonfia.csv nonfia nonfia

# sensitivity: inventory period (FIA 2019-2023, CCI 2021)
Rscript 02_reference/01_fia_canopy_intervals.R 2019 2023
Rscript 02_reference/02_products_and_reference.R 2019 2023 2021
Rscript 03_predictors/04_analysis_tables.R 2019_2023_cci2021 2019_2023_cci2021 period
Rscript 03_predictors/04_analysis_tables.R 2018_2022_cci2020 2019_2023_cci2021 splitA
Rscript 03_predictors/04_analysis_tables.R 2019_2023_cci2021 2018_2022_cci2020 splitB
python 04_models/01_bias_model.py output/03_predictors/analysis_period_main.csv period
python 04_models/01_bias_model.py output/03_predictors/analysis_splitA_main.csv splitA
python 04_models/01_bias_model.py output/03_predictors/analysis_splitB_main.csv splitB

Rscript 05_sensitivity/01_forest_loss.R
python 05_sensitivity/02_scale.py
python 05_sensitivity/03_period_summary.py

Rscript 06_figures_tables/fig1_study_area.R
Rscript 06_figures_tables/fig2_accuracy_and_bias.R
Rscript 06_figures_tables/fig3_shap_and_response.R
Rscript 06_figures_tables/fig4_dominant_factor.R
Rscript 06_figures_tables/figS1_tribal_land_accuracy.R
python 06_figures_tables/figS3_response_curves.py
python 06_figures_tables/fig5_correction_performance.py
python 06_figures_tables/table_S1.py
python 06_figures_tables/manuscript_numbers.py
```

## Configuration

`config.yml` lists every raw input and every analysis setting (selection thresholds, years, region boxes,
random seed 42). Set `input_dir` to the folder that holds the raw data. Paths in `inputs:` are relative to it.
Python scripts read the same file (`py/common.py`), which also fixes the predictor order and the XGBoost search
space.

## Building the soil-moisture input

Every input except soil moisture is used as downloaded. The soil-moisture layer (`inputs: smap_sm_2021`) is a
2021 annual mean that has to be built from the daily SMAP files:

1. Download the daily granules of SMAP Enhanced L3 Radiometer Global Daily 9 km EASE-Grid Soil Moisture,
   Version 6 (SPL3SMP_E; https://doi.org/10.5067/M20OXIZHY3RJ; NASA Earthdata login required) for
   1 January to 31 December 2021.
2. From each granule, read the surface (0–5 cm) volumetric soil moisture of the AM and PM overpasses
   (`Soil_Moisture_Retrieval_Data_AM/soil_moisture` and `Soil_Moisture_Retrieval_Data_PM/soil_moisture_pm`;
   −9999 = no retrieval).
3. Average all valid 2021 values in each 9 km cell. The result is one global layer on the EASE-Grid 2.0 global
   grid (EPSG:6933), in m³ m⁻³.
4. Project it to longitude/latitude (EPSG:4326; `terra::project`, bilinear), crop it to the conterminous
   United States (longitude −125 to −66.5, latitude 24 to 49), and save it as GeoTIFF under the path given for
   `smap_sm_2021` in `config.yml`.

Stage 03 then averages the layer over each hexagon. Steps 2–3 are a reasonable default, not a record of what
the paper did (see Reproducibility notes).

## Reproducibility notes

- **Checked against the paper.** Every stage was run from the raw inputs and compared with the published
  results. Stages 01–03 reproduce the published analysis tables (study area, reference and satellite AGB, study
  regions, the sensitivity layers, and nine of the ten predictors) to floating-point precision; soil moisture
  is the exception (next note). On the published analysis tables, stages 04–06 reproduce the published bias,
  regional and global models (CV scores, SHAP values, out-of-fold predictions), the inventory-period runs,
  Tables S1–S2, the values behind Figs. 5 and S5, the numbers quoted in the text, and the figures. Exact
  agreement assumes the package versions listed under Software.
- **Soil moisture.** The SMAP 2021 mean raster used in the paper was not kept, and how the daily values were
  averaged (which overpasses, any quality screening) was not recorded, so a rebuilt raster (see "Building the
  soil-moisture input") will not match it exactly. The rebuild used to test this code agrees closely with the
  published hexagon values (r = 0.995, largest difference 0.04 m³ m⁻³); with it, a full rerun moves a few
  published numbers slightly (for example, the CCI bias model's elevation importance is 4.9 instead of
  5.2 Mg ha⁻¹, and the NM+SECP CCI regional model's CV R² is −0.23 instead of −0.26).
- **Terrain.** Slope and aspect are computed tile by tile (1° ASTER GDEM tiles). A hexagon that crosses a tile
  edge takes the plain mean of the means of its parts in each tile.
- **Which part of the hexagon.** Forest age (TreeMap) and the GLAD canopy height use the part of the hexagon
  inside the tribal land; all other predictors use the whole hexagon.
- **TreeMap stand age.** Age in 2020 = FIADB `STDAGE` + (2020 − `MEASYEAR`). Plots whose result is negative
  are set to 0.
- **Large numbers in `config.yml`.** Write them as plain digits. The YAML readers used here read `1.0e8` as
  text, not as a number.

## Data sources

All inputs are public. They are not included in this repository because of their size.

| Input | Source |
|---|---|
| FIA database (FIADB v9.3, SQLite) | USDA Forest Service FIA DataMart |
| FIA hexagon grid (64,000 ha) | Menlove & Healey (2020), USDA Forest Service Research Data Archive |
| Tribal lands | U.S. Census Bureau, 2024 TIGER/Line Shapefiles, American Indian/Alaska Native/Native Hawaiian Areas |
| Ecological provinces | USDA Forest Service ECOMAP (2007), ecological subregions of the United States |
| NLCD Tree Canopy Cover, 2020 and 2021 (v2025-6) | USDA Forest Service / MRLC |
| GEDI L4B gridded AGB v2.1 (1 km) | ORNL DAAC |
| ESA CCI Biomass v6.0, 2020 and 2021 (100 m) | ESA Climate Change Initiative, CEDA archive |
| TreeMap 2020 (plot imputation raster, stand height, stand density index) | USDA Forest Service Research Data Archive |
| ASTER GDEM v3 | NASA LP DAAC |
| GEDI L4C gridded WSCI (1 km) | ORNL DAAC |
| Community wood density map | Mo et al. (2024) |
| gNATSGO available water capacity | USDA NRCS |
| SMAP enhanced L3 soil moisture (SPL3SMP_E v6, daily 2021; see "Building the soil-moisture input") | NASA NSIDC DAAC |
| Forest stand age 2011 (sensitivity) | Pan et al. (2011), USDA Forest Service Research Data Archive |
| GLAD forest canopy height 2019 (sensitivity) | Potapov et al. (2021) |
| GAMI forest age v2.1 (sensitivity) | Besnard et al. (2024), GFZ Data Services |
| Tree density (sensitivity) | Crowther et al. (2015) |
| Global Forest Change v1.12 (forest loss) | Hansen et al. (2013) |

## Software

R 4.5.2: terra 1.9.46, sf 1.0.21, exactextractr 0.10.0, data.table 1.17.8, rFIA 1.1.2, yaml 2.3.10, DBI,
RSQLite 2.4.3, future.apply 1.20.0, ggplot2 4.0.0, patchwork 1.3.2, dplyr 1.1.4, rnaturalearth 1.1.0.
Python 3.11: numpy 2.3.3, pandas 2.3.3, scipy 1.16.2, scikit-learn 1.7.2, xgboost 3.1.3, shap 0.51.0,
matplotlib 3.10.7, pyyaml 6.0.3.

## License

MIT (see `LICENSE`).
