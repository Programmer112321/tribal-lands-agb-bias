# 01 — Elevation, slope and northness per hexagon from ASTER GDEM v3 (Section 2.4)
#
# Each 1-degree DEM tile is processed on its own, as in the paper:
#   slope (degrees) and aspect (radians) with terra::terrain on the tile; northness = cos(aspect);
#   slope and northness are stored as 32-bit floats (as in the original processing);
#   for every hexagon part inside the tile, the mean of each layer over the cells whose centre lies in the part.
# The hexagon value is the mean of its tile-part means (unweighted).
#
# Usage : Rscript 03_predictors/01_terrain.R
# Input : output/01_study_area/study_hexagons.csv; ASTER GDEM tiles (config: aster_gdem_dir)
# Output: output/03_predictors/terrain.csv  (FID, Elevation, Slope, Northness)
suppressPackageStartupMessages(library(future.apply))
source("R/setup.R")

fids <- sort(unique(fread(out("01_study_area", "study_hexagons.csv"))$FID))
HEX  <- inp("fia_hexagons")
hex  <- vect(HEX)[, "FID"]
hex  <- hex[hex$FID %in% fids, ]

# tiles whose 1-degree box can touch a study hexagon (tile name gives the lower-left corner)
tiles <- list.files(file.path(CFG$input_dir, CFG$inputs$aster_gdem_dir), pattern = "_dem[.]tif$", full.names = TRUE)
code  <- regmatches(basename(tiles), regexpr("[NS][0-9]{2}[EW][0-9]{3}", basename(tiles)))
lat   <- as.integer(substr(code, 2, 3)) * ifelse(substr(code, 1, 1) == "S", -1, 1)
lon   <- as.integer(substr(code, 5, 7)) * ifelse(substr(code, 4, 4) == "W", -1, 1)
bb    <- do.call(rbind, lapply(seq_along(hex), function(i) as.vector(ext(hex[i]))))   # xmin xmax ymin ymax
near  <- vapply(seq_along(tiles), function(i)
  any(bb[, 1] < lon[i] + 1.01 & bb[, 2] > lon[i] - 0.01 & bb[, 3] < lat[i] + 1.01 & bb[, 4] > lat[i] - 0.01), logical(1))
tiles <- tiles[near]
msg(length(tiles), "DEM tiles near", length(hex), "hexagons")

one_tile <- function(f) {
  suppressPackageStartupMessages({ library(terra); library(data.table) })
  terraOptions(progress = 0, memfrac = 0.05)
  h   <- vect(HEX)[, "FID"]; h <- h[h$FID %in% fids, ]
  dem <- rast(f)
  parts <- terra::intersect(h, as.polygons(ext(dem), crs = crs(dem)))
  if (length(parts) == 0) return(NULL)
  tmp <- tempfile(fileext = ".tif")
  on.exit(unlink(tmp))
  sn  <- c(terrain(dem, v = "slope", unit = "degrees"), cos(terrain(dem, v = "aspect", unit = "radians")))
  sn  <- writeRaster(sn, tmp, datatype = "FLT4S")
  z   <- zonal(c(dem, sn), parts, fun = "mean", na.rm = TRUE)
  data.table(FID = parts$FID, Elevation = z[[1]], Slope = z[[2]], Northness = z[[3]])
}

plan(multisession, workers = SET$workers)
parts <- rbindlist(future_lapply(tiles, one_tile, future.seed = TRUE))
plan(sequential)

res <- parts[, lapply(.SD, mean), by = FID, .SDcols = c("Elevation", "Slope", "Northness")][order(FID)]
fwrite(res, out("03_predictors", "terrain.csv"))
msg("terrain:", nrow(res), "hexagons from", nrow(parts), "tile parts; missing:", sum(!complete.cases(res)))
