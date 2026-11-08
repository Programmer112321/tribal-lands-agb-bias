# 03 — Product-independent reference AGB per hexagon, for the map in Fig. 1
#
# As script 02, but over all NLCD 2020 forest pixels (tree canopy cover > 10%) of each hexagon piece instead of the
# pixels inside retained product cells: every forest pixel gets the FIA AGB of its canopy-cover interval (script 01;
# pixels outside every interval count as 0), the piece value is the mean over its forest pixels, and the hexagon
# value is the forest-pixel-weighted mean over the pieces that hold forested FIA plots.
#
# Usage : Rscript 02_reference/03_forest_area_reference.R
# Output: output/02_reference/forest_area_reference_2018_2022.csv  (FID, ref_forest_area, n_forest_pixels)
suppressPackageStartupMessages({ library(sf); library(exactextractr); library(future.apply) })
source("R/setup.R")

tag    <- paste(SET$reference_years, collapse = "_")
thr    <- SET$forest_canopy_threshold
PIECES <- out("02_reference", "reference_pieces.gpkg")
TCC    <- inp("nlcd_tcc_2020")

one_piece <- function(fidp) {
  suppressPackageStartupMessages({ library(terra); library(sf); library(exactextractr); library(data.table) })
  terraOptions(progress = 0, memfrac = 0.05)
  h  <- vect(PIECES); h <- h[h$FIDP == fidp, ]
  tr <- rast(TCC)
  tc <- crop(tr, buffer(project(h, crs(tr)), 3000), snap = "out")
  v  <- exact_extract(ifel(tc > 101, NA, tc), st_as_sf(project(h, crs(tr))), progress = FALSE)[[1]]$value
  v  <- v[!is.na(v) & v > thr]
  if (!length(v)) return(NULL)
  tb <- table(v)
  data.table(FIDP = fidp, tcc = as.numeric(names(tb)), n = as.numeric(tb))
}

plan(multisession, workers = SET$workers)
pix <- rbindlist(future_lapply(vect(PIECES)$FIDP, one_piece, future.seed = TRUE))
plan(sequential)

iv  <- fread(out("02_reference", paste0("canopy_intervals_", tag, ".csv")))
ref <- iv[pix, on = .(FIDP, lower <= tcc, upper >= tcc), .(FIDP = i.FIDP, n = i.n, BIO_Mg_ha = x.BIO_Mg_ha)]
ref <- ref[, .(ref = sum(n * fifelse(is.na(BIO_Mg_ha), 0, BIO_Mg_ha)) / sum(n), n_px = sum(n)), by = FIDP]
ref <- ref[FIDP %in% iv$FIDP]                                       # pieces with forested FIA plots
ref <- ref[, .(ref_forest_area = sum(ref * n_px) / sum(n_px), n_forest_pixels = sum(n_px)),
           by = .(FID = as.integer(tstrsplit(FIDP, "_", fixed = TRUE)[[1]]))]
fwrite(ref[order(FID)], out("02_reference", paste0("forest_area_reference_", tag, ".csv")))
msg("forest-area reference:", nrow(ref), "hexagons; mean", round(mean(ref$ref_forest_area), 2), "Mg/ha")
