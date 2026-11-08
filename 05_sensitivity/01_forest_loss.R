# 01 — Recent forest loss per hexagon (Section 2.3)
#
# Forest loss 2019-2023 as a share of the forest area of the hexagon:
#   loss area   = area of Hansen GFC v1.12 pixels with loss year 2019-2023 (lossyear 19-23)
#   forest area = area of NLCD 2020 30-m pixels with tree canopy cover > 10% (codes > 100 count as non-forest)
# Both are coverage-weighted sums over the whole hexagon (exactextractr).
#
# Usage : Rscript 05_sensitivity/01_forest_loss.R
# Output: output/05_sensitivity/forest_loss.csv (FID, loss_m2, forest_m2, loss_share); prints mean / median over
#         the hexagons of the main analysis table
suppressPackageStartupMessages({ library(sf); library(exactextractr); library(future.apply) })
source("R/setup.R")

fids  <- sort(unique(fread(out("01_study_area", "study_hexagons.csv"))$FID))
PIECE <- out("01_study_area", "hexagon_province_pieces.gpkg")
TCC   <- inp("nlcd_tcc_2020")
VRT   <- file.path(tempdir(), "hansen_lossyear.vrt")
vrt(list.files(file.path(CFG$input_dir, CFG$inputs$hansen_lossyear_dir), "lossyear.*[.]tif$", full.names = TRUE),
    VRT, overwrite = TRUE)

one_hex <- function(fid) {
  suppressPackageStartupMessages({ library(terra); library(sf); library(exactextractr) })
  terraOptions(progress = 0, memfrac = 0.05)
  h  <- vect(PIECE); h <- aggregate(h[h$FID == fid, ], by = "FID")
  tr <- rast(TCC)
  tc <- crop(tr, buffer(project(h, crs(tr)), 3000), snap = "out")
  fo <- ifel(ifel(tc > 101, 0, tc) > 10, 1, 0)
  forest_m2 <- exact_extract(fo * cellSize(fo, unit = "m"), st_as_sf(project(h, crs(tr))), "sum", progress = FALSE)
  ly <- rast(VRT)
  ly <- crop(ly, buffer(project(h, crs(ly)), 3000), snap = "out")
  la <- ifel(ly >= 19 & ly <= 23, 1, 0) * cellSize(ly, unit = "m")
  loss_m2 <- exact_extract(la, st_as_sf(project(h, crs(ly))), "sum", progress = FALSE)
  data.frame(FID = fid, loss_m2 = loss_m2, forest_m2 = forest_m2, loss_share = loss_m2 / max(forest_m2, 1))
}

plan(multisession, workers = SET$workers)
res <- rbindlist(future_lapply(fids, one_hex, future.seed = TRUE))
plan(sequential)
fwrite(res, out("05_sensitivity", "forest_loss.csv"))

main <- unique(fread(out("03_predictors", "analysis_main_main.csv"))$FID)
x <- res[FID %in% main]
msg(sprintf("forest loss 2019-2023, %d hexagons: mean %.1f%%, median %.1f%% of the forest area",
            nrow(x), 100 * mean(x$loss_share), 100 * median(x$loss_share)))
