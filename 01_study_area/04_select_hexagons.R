# 04 — Select the study hexagons (Section 2.1)
#
# A tribal-land x hexagon piece is kept when
#   * its hexagon contains at least four forested FIA plot measurements from 2019-2023,
#   * its overlap with the tribal land is more than one-sixth of the largest piece (~108 km² of a 640-km² hexagon),
#   * it holds at least 9 ha of NLCD 2021 forest (a safety filter; it removes no piece in this study);
# and the tribal land keeps at least six such pieces. A hexagon that overlaps two tribal lands can be kept for both.
#
# Inputs : output/01_study_area/fia_plot_agb_2018_2023.csv (01), tribal_land_hexagon_pieces.gpkg (03)
# Output : output/01_study_area/study_hexagons.csv  (one row per tribal land x hexagon; 259 hexagons, 20 tribal lands)
source("R/setup.R")

# forested plot measurements per (whole) hexagon, 2019-2023
yr <- SET$selection_plot_years
plots <- fread(out("01_study_area", "fia_plot_agb_2018_2023.csv"))[between(YEAR, yr[1], yr[2]) & !is.na(LAT)]
hex <- vect(inp("fia_hexagons"))[, "FID"]
pv <- project(vect(plots, geom = c("LON", "LAT"), crs = "EPSG:4326"), crs(hex))
n_plots <- data.table(FID = extract(hex, pv)$FID)[!is.na(FID), .(n_plots_2019_2023 = .N), by = FID]

pieces <- as.data.table(as.data.frame(vect(out("01_study_area", "tribal_land_hexagon_pieces.gpkg"))))
pieces <- merge(pieces, n_plots, by = "FID", all.x = TRUE)
pieces[is.na(n_plots_2019_2023), n_plots_2019_2023 := 0L]

min_overlap <- max(pieces$overlap_area_m2) * SET$min_overlap_fraction
cand <- pieces[n_plots_2019_2023 >= SET$min_plots &
               overlap_area_m2 > min_overlap &
               forest_area_m2 > SET$min_forest_area_m2]
keep_tribes <- cand[, .N, by = tribe][N >= SET$min_hexagons_per_tribal_land, tribe]
sel <- cand[tribe %in% keep_tribes][order(tribe, FID)]

fwrite(sel[, .(tribe, GEOID, FID, overlap_area_m2, forest_area_m2, n_plots_2019_2023)],
       out("01_study_area", "study_hexagons.csv"))
msg(sprintf("minimum overlap %.1f km² | selected: %d rows, %d hexagons, %d tribal lands",
            min_overlap / 1e6, nrow(sel), uniqueN(sel$FID), uniqueN(sel$tribe)))
msg("pieces failing only the forest-area filter:",
    nrow(pieces[n_plots_2019_2023 >= SET$min_plots & overlap_area_m2 > min_overlap & !(forest_area_m2 > SET$min_forest_area_m2)]))
