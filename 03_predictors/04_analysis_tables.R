# 04 — Analysis tables: bias, reference and predictors per hexagon and product; study regions (Sections 2.1, 2.5)
#
# Rows: one per hexagon and product (GEDI, CCI), sorted by FID. A hexagon is kept when both products have a
# satellite value and a reference (257 hexagons in the main analysis). A hexagon that overlaps two tribal lands
# is assigned to the one listed first in the TIGER/Line file.
#   AGB REF  reference AGB (Mg/ha);  AGB = satellite AGB - AGB REF (the bias);  Product uncertainty (GEDI SE, CCI SD)
#   predictors from scripts 01-03; Plot number = forested FIA plot measurements 2019-2023 in the hexagon;
#   x, y = hexagon centroid (lon/lat).
# Three predictor sets (same rows):
#   main    forest age = TreeMap 2020
#   pan     forest age = Pan et al. (2015), 2011 map              (forest-age comparison)
#   nonfia  canopy height = GLAD 2019, forest age = GAMI 2020,
#           stand density = Crowther et al. (2015)               (layers not built from FIA plots, Table S2)
#
# Usage : Rscript 03_predictors/04_analysis_tables.R [sat_run ref_run tag]
#   sat_run / ref_run: stage-02 runs ("<first>_<last>_cci<year>") that give the satellite values and the
#   reference; default 2018_2022_cci2020 for both, tag "main". Sensitivity runs: see 05_sensitivity/.
# Outputs: output/03_predictors/analysis_<tag>_{main,pan,nonfia}.csv; output/03_predictors/regions.csv
source("R/setup.R")

a       <- commandArgs(TRUE)
sat_run <- if (length(a) >= 1) a[1] else "2018_2022_cci2020"
ref_run <- if (length(a) >= 2) a[2] else sat_run
tag     <- if (length(a) >= 3) a[3] else "main"

# satellite and reference per hexagon x product
pr  <- function(run) fread(out("02_reference", paste0("products_reference_", run, ".csv")))
pr  <- merge(pr(sat_run)[, .(FID, product, sat, unc)], pr(ref_run)[, .(FID, product, ref)], by = c("FID", "product"))
ok  <- pr[!is.na(sat) & !is.na(ref), .N, by = FID][N == 2, FID]
pr  <- pr[FID %in% ok]

# one tribal land per hexagon: first in TIGER/Line record order
tiger <- as.data.table(as.data.frame(vect(inp("tribal_lands"))))[, .(GEOID, rec = .I)]
sel   <- merge(fread(out("01_study_area", "study_hexagons.csv")), tiger, by = "GEOID")
sel   <- sel[order(rec)][!duplicated(FID), .(FID, Tribe = tribe, `Plot number` = n_plots_2019_2023)]

# hexagon centroids (lon/lat)
hex <- vect(inp("fia_hexagons"))[, "FID"]
hex <- hex[hex$FID %in% sel$FID, ]
xy  <- data.table(FID = hex$FID, crds(centroids(hex)))

# predictors
pred <- Reduce(function(x, y) merge(x, y, by = "FID"), list(
  fread(out("03_predictors", "terrain.csv")),
  fread(out("03_predictors", "raster_predictors.csv")),
  fread(out("03_predictors", "treemap_stand_age.csv"))))

base <- Reduce(function(x, y) merge(x, y, by = "FID"), list(sel, xy, pred))
d <- merge(pr, base, by = "FID")
d[, `:=`(`AGB product` = product, `AGB REF` = ref, AGB = sat - ref, `Product uncertainty` = unc)]
d <- d[order(FID, -rank(product))]                    # GEDI before CCI within a hexagon

COLS <- c("FID", "Canopy height", "Forest age", "Soil moisture", "AWC", "Stand density", "Wood density",
          "Structural diversity", "Elevation", "Slope", "Northness", "Forest age SD", "Wood density SD",
          "AGB REF", "Plot number", "x", "y", "Tribe", "AGB product", "AGB", "Product uncertainty")
main <- d[, ..COLS]
pan  <- copy(main)[, `:=`(`Forest age` = d$`Pan forest age`, `Forest age SD` = d$`Pan forest age SD`)]
nonf <- copy(main)[, `:=`(`Canopy height` = d$`Canopy height GLAD`, `Forest age` = d$`Forest age GAMI`,
                          `Stand density` = d$`Stand density Crowther`)]
for (s in c("main", "pan", "nonfia"))
  fwrite(list(main = main, pan = pan, nonfia = nonf)[[s]], out("03_predictors", sprintf("analysis_%s_%s.csv", tag, s)))

# study regions (all selected hexagons): centroid in a region box, else the region of its tribal land
if (tag == "main") {
  B   <- CFG$settings$regions
  reg <- merge(sel[, .(FID, Tribe)], xy, by = "FID")
  reg[, Region_orig := NA_character_]
  for (r in names(B)) { b <- unlist(B[[r]]); reg[x >= b[1] & x <= b[2] & y >= b[3] & y <= b[4], Region_orig := r] }
  fill <- reg[!is.na(Region_orig), .N, by = .(Tribe, Region_orig)][order(-N)][!duplicated(Tribe)]
  fill <- setNames(fill$Region_orig, fill$Tribe)
  reg[is.na(Region_orig), Region_orig := fill[Tribe]]
  reg[, Region := unlist(CFG$settings$merged_regions)[Region_orig]]
  # hexagon area inside tribal lands (all tribal-land pieces of the hexagon), for the Tg totals
  pcs <- as.data.table(as.data.frame(vect(out("01_study_area", "tribal_land_hexagon_pieces.gpkg"))))
  reg <- merge(reg, pcs[, .(tribal_area_ha = sum(overlap_area_m2) / 1e4), by = FID], by = "FID", all.x = TRUE)
  fwrite(reg[order(FID), .(FID, Tribe, x, y, Region, Region_orig, tribal_area_ha)], out("03_predictors", "regions.csv"))
  print(reg[, .N, by = .(Region, Region_orig)])
}
msg(sprintf("analysis tables '%s' (satellite %s, reference %s): %d hexagons, %d rows",
            tag, sat_run, ref_run, uniqueN(main$FID), nrow(main)))
print(main[, .(hexagons = .N, mean_ref = mean(`AGB REF`), bias = mean(AGB), RMSE = sqrt(mean(AGB^2))), by = `AGB product`])
