# 03 — Tribal lands x FIA hexagons (Section 2.1)
#
# Tribal lands: 2024 TIGER/Line American Indian/Alaska Native/Native Hawaiian Areas in the conterminous
# U.S. with land area (ALAND) > 100 km². Each tribal land is intersected with the FIA hexagons; for every
# tribal-land x hexagon piece we compute its area and its NLCD 2021 forest area
# (forest = tree canopy cover > 10%; sum of 30-m cell areas of forest cells inside the piece).
#
# Output: output/01_study_area/tribal_land_hexagon_pieces.gpkg
#   tribe (NAME), GEOID, FID, overlap_area_m2, forest_area_m2
source("R/setup.R")

e <- SET$conus_extent
tribal <- vect(inp("tribal_lands"))
tribal <- crop(project(tribal, "EPSG:4326"), ext(e[1], e[2], e[3], e[4]))
tribal <- tribal[tribal$ALAND > SET$min_tribal_land_area_m2, c("NAME", "GEOID")]
names(tribal)[1] <- "tribe"

hex <- project(vect(inp("fia_hexagons"))[, "FID"], crs(tribal))
pieces <- terra::intersect(tribal, hex)
pieces$overlap_area_m2 <- expanse(pieces, unit = "m")
msg("tribal lands:", length(tribal), "| tribal-land x hexagon pieces:", length(pieces))

# forest area per piece, one tribal land at a time (keeps the 30-m raster small)
tcc <- rast(inp("nlcd_tcc_2021"))
pieces$forest_area_m2 <- NA_real_
for (g in unique(pieces$GEOID)) {
  i <- which(pieces$GEOID == g)
  p <- project(pieces[i], crs(tcc))
  r <- crop(tcc, p, snap = "out")
  forest_area <- ifel(r > 10 & r < 254, 1, 0) * cellSize(r, unit = "m")
  pieces$forest_area_m2[i] <- zonal(forest_area, p, fun = "sum", na.rm = TRUE)[, 1]
}

writeVector(pieces, out("01_study_area", "tribal_land_hexagon_pieces.gpkg"), overwrite = TRUE, options = "FID=gpkg_fid")
msg("done; pieces with forest area > 0:", sum(pieces$forest_area_m2 > 0))
