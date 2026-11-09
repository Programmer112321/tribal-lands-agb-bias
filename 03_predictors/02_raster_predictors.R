# 02 — Hexagon means of the raster predictors (Section 2.4)
#
# Mean over all raster cells whose centre lies in the hexagon (terra::zonal, NA cells ignored):
#   Canopy height          TreeMap 2020 stand height (feet x 0.3048 = m)
#   Stand density          TreeMap 2020 stand density index
#   Wood density (+ SD)    community wood density (g/cm³); SD = standard deviation over the hexagon
#   Structural diversity   GEDI L4C mean WSCI estimate
#   AWC                    gNATSGO available water capacity (mm/m)
#   Soil moisture          SMAP 2021 mean soil moisture (m³/m³)
#   Pan forest age (+ SD)  Pan et al. (2015) 2011 stand age, used only in the forest-age comparison
# Layers not built from FIA plots (sensitivity analysis, Table S2):
#   GLAD canopy height 2019  mean over tree pixels (5-60 m) of the hexagon part inside tribal lands
#   GAMI forest age 2020     mean over the 20 ensemble members of each member's mean over forest pixels
#   Crowther tree density    mean over the hexagon
#
# Usage : Rscript 03_predictors/02_raster_predictors.R
# Inputs: output/01_study_area/study_hexagons.csv, tribal_land_hexagon_pieces.gpkg, hexagon_province_pieces.gpkg
# Output: output/03_predictors/raster_predictors.csv (one row per study hexagon)
source("R/setup.R")

fids  <- sort(unique(fread(out("01_study_area", "study_hexagons.csv"))$FID))
hex   <- vect(inp("fia_hexagons"))[, "FID"]
hex   <- hex[hex$FID %in% fids, ]
# hexagon part inside tribal lands (all tribal-land pieces of the hexagon, dissolved)
tribal <- vect(out("01_study_area", "tribal_land_hexagon_pieces.gpkg"))
tribal <- aggregate(tribal[tribal$FID %in% fids, ], by = "FID")
# whole hexagon as the union of its ecological-province pieces
whole  <- vect(out("01_study_area", "hexagon_province_pieces.gpkg"))
whole  <- aggregate(whole[whole$FID %in% fids, ], by = "FID")

zmean <- function(r, poly = hex, fun = "mean") {
  p <- if (same.crs(r, poly)) poly else project(poly, crs(r))
  data.table(FID = p$FID, v = zonal(r, p, fun = fun, na.rm = TRUE)[[1]])
}
col <- function(d, name) setnames(d, "v", name)[]

res <- list(
  col(zmean(rast(inp("treemap_standht")))[, v := 0.3048 * v], "Canopy height"),       # feet -> m
  col(zmean(rast(inp("treemap_sdi"))), "Stand density"),
  col(zmean(rast(inp("wood_density"))), "Wood density"),
  col(zmean(rast(inp("wood_density")), fun = "sd"), "Wood density SD"),
  col(zmean(rast(inp("gedi_l4c_wsci"))[[1]]), "Structural diversity"),
  col(zmean(rast(inp("gnatsgo_awc"))), "AWC"),
  col(zmean(rast(inp("smap_sm_2021"))), "Soil moisture"),
  col(zmean(rast(inp("pan_forest_age_2011"))), "Pan forest age"),
  col(zmean(rast(inp("pan_forest_age_2011")), fun = "sd"), "Pan forest age SD"))
msg("FIA-based and abiotic layers done")

# GLAD 2019 canopy height: tree pixels only (codes > 60 = water / no data; < 5 m = not tree)
glad <- rast(inp("glad_canopy_height_2019"))
th   <- SET$glad_tree_height
tree_mean <- function(v, ...) { v <- v[!is.na(v) & v >= th[1] & v <= th[2]]; if (length(v)) mean(v) else NA_real_ }
p <- project(tribal, crs(glad))
res[[length(res) + 1]] <- data.table(FID = p$FID, `Canopy height GLAD` = extract(glad, p, fun = tree_mean, ID = FALSE)[[1]])
msg("GLAD done")

# GAMI 2020 forest age: 20 ensemble members (layers ending in _2 = 2020); negative values = no forest
gami <- rast(inp("gami_forest_age"))
gami <- gami[[grep("_2$", names(gami))]]
stopifnot(nlyr(gami) == 20)
valid_mean <- function(x, ...) { x <- x[!is.na(x) & x >= 0]; if (length(x)) mean(x) else NA_real_ }
p <- project(whole, crs(gami))
m <- as.matrix(extract(gami, p, fun = valid_mean, ID = FALSE))   # slow (~1 h): compressed global file
res[[length(res) + 1]] <- data.table(FID = p$FID, `Forest age GAMI` = rowMeans(m, na.rm = TRUE))
msg("GAMI done")

# Crowther et al. (2015) tree density
cr <- rast(inp("crowther_tree_density"))
p  <- project(whole, crs(cr))
res[[length(res) + 1]] <- data.table(FID = p$FID, `Stand density Crowther` = extract(cr, p, fun = mean, na.rm = TRUE, ID = FALSE)[[1]])

x <- Reduce(function(a, b) merge(a, b, by = "FID", all = TRUE), res)
fwrite(x, out("03_predictors", "raster_predictors.csv"))
msg("raster predictors:", nrow(x), "hexagons;", ncol(x) - 1, "columns; missing values per column:")
print(colSums(is.na(x[, -"FID"])))
