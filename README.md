# Local-scale bias in global forest aboveground biomass products on Tribal lands

Code for: Chu, D., et al. *Local-scale bias in global products of forest aboveground biomass related to
structural diversity and stand density.* Remote Sensing of Environment (under review, RSE-D-26-03577).

The analysis compares two global aboveground biomass (AGB) products, GEDI L4B v2.1 (1 km) and ESA CCI Biomass
v6.0 (2020, 100 m), with a reference AGB built from USDA Forest Service Forest Inventory and Analysis (FIA)
plots in 257 FIA hexagons on 20 Tribal lands in the conterminous United States. It then explains the bias with
ten forest and site factors (XGBoost + SHAP) and tests bias-correction models.

> **Status:** under construction. Stages are added one at a time; each is checked against the results
> reported in the paper before the next one is added.
>
> **Not yet updated:** `02_reference/02_products_and_reference.R` still uses the reference rule of an earlier
> draft (hexagon pieces without FIA plots count as 0, and pieces are weighted equally). The revised manuscript
> uses the pixel-weighted mean over the pieces that contain forested FIA plots. Do not use the stage-02 output
> until this is changed.

## Layout and run order

Run every script from the repository root, in numeric order. R scripts: `Rscript <folder>/<script>.R`.

| Stage | Script | What it does | Paper |
|---|---|---|---|
| 01 study area | `01_study_area/01_fia_plot_agb.R` | Plot-level forest AGB from FIA (rFIA), 2018–2023 | 2.3 |
| | `01_study_area/02_hexagon_province_pieces.R` | FIA hexagons split by USFS ecological province | 2.3 |
| | `01_study_area/03_tribal_land_pieces.R` | Tribal lands × hexagons; overlap and forest area | 2.1 |
| | `01_study_area/04_select_hexagons.R` | Study hexagons (259 on 20 Tribal lands) | 2.1 |
| 02 reference | `02_reference/01_fia_canopy_intervals.R` | FIA plot AGB by canopy cover; canopy-cover intervals per hexagon piece | 2.3 |
| | `02_reference/02_products_and_reference.R` | Forest mask; satellite AGB and product-matched reference per hexagon | 2.1, 2.3 |
| 03 predictors | *to be added* | | |
| 04 models | *to be added* | | |
| 05 sensitivity | *to be added* | | |
| 06 figures and tables | *to be added* | | |

Outputs go to `output/<stage>/` (not tracked by git).

## Configuration

`config.yml` lists every raw input and every analysis setting (selection thresholds, years, random seed 42).
Set `input_dir` to the folder that holds the raw data. Paths in `inputs:` are relative to it.

## Data sources

All inputs are public. They are not included in this repository because of their size.

| Input | Source |
|---|---|
| FIA database (FIADB v9.3, SQLite) | USDA Forest Service FIA DataMart |
| FIA hexagon grid (64,000 ha) | Menlove & Healey (2020), USDA Forest Service Research Data Archive |
| Tribal lands | U.S. Census Bureau, 2024 TIGER/Line Shapefiles, American Indian/Alaska Native/Native Hawaiian Areas |
| Ecological provinces | USDA Forest Service ECOMAP (2007), ecological subregions of the United States |
| NLCD Tree Canopy Cover, 2020 and 2021 (v2025-6) | USDA Forest Service / MRLC |

*(The list will grow with the remaining stages.)*

## Software

R 4.5.2: terra 1.9.46, sf 1.0.21, data.table 1.17.8, rFIA 1.1.2, yaml 2.3.10, DBI, RSQLite 2.4.3.
Python 3.11 (later stages): see `environment.yml`.

## License

To be decided.
