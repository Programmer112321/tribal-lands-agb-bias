# 02 — Split FIA hexagons by USFS ecological province (used for the reference AGB, Section 2.3)
#
# A hexagon that lies within one ecological province is kept whole. A hexagon that crosses province
# boundaries is split into its province pieces when at least one piece contains more than one FIA
# forest plot measured in 2019-2023 (the plot years of the hexagon selection); otherwise it is kept whole.
# (All pieces of a split hexagon are kept, including pieces with fewer plots.) The reference is computed per
# piece and averaged per hexagon.
# Check: identical to the pieces used in the paper for all 259 study hexagons (11 coastal hexagons elsewhere,
# with a "Water" province piece, differ slightly).
#
# Input : output/01_study_area/fia_plot_agb_2018_2023.csv (script 01)
# Output: output/01_study_area/hexagon_province_pieces.gpkg   (FID, PROVINCE_N; PROVINCE_N empty = whole hexagon)
source("R/setup.R")

prov <- vect(inp("eco_provinces"))[, "PROVINCE_N"]
hex  <- project(vect(inp("fia_hexagons"))[, "FID"], crs(prov))

# hexagons not entirely within one province, cut by the province boundaries
within_one <- rowSums(relate(hex, prov, relation = "within")) > 0
pieces <- terra::intersect(prov, hex[!within_one])
multi_fid <- as.data.table(as.data.frame(pieces))[, .N, by = FID][N > 1, FID]
pieces <- pieces[pieces$FID %in% multi_fid]

# FIA forest plots 2019-2023 per piece
b  <- SET$conus_bbox
yr <- SET$selection_plot_years
plots <- fread(out("01_study_area", "fia_plot_agb_2018_2023.csv"))[
  between(YEAR, yr[1], yr[2]) & LON >= b[1] & LON <= b[2] & LAT >= b[3] & LAT <= b[4]]
pv <- project(vect(plots, geom = c("LON", "LAT"), crs = "EPSG:4326"), crs(prov))
hit <- as.data.table(as.data.frame(terra::intersect(pv[, "PLT_CN"], pieces)))
n_plot <- hit[, .N, by = .(PROVINCE_N, FID)]
split_fid <- unique(n_plot[N > 1, FID])

kept_pieces <- pieces[pieces$FID %in% split_fid]
whole <- hex[!hex$FID %in% split_fid]
whole$PROVINCE_N <- NA_character_
res <- rbind(kept_pieces[, c("FID", "PROVINCE_N")], whole[, c("FID", "PROVINCE_N")])

writeVector(res, out("01_study_area", "hexagon_province_pieces.gpkg"), overwrite = TRUE, options = "FID=gpkg_fid")
msg("hexagons:", length(hex), "| split into province pieces:", length(split_fid),
    "| features written:", nrow(res))
