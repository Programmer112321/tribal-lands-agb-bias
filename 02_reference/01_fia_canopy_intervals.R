# 01 — FIA plot AGB by canopy cover, and canopy-cover intervals per hexagon piece (Section 2.3)
#
# Plot-level AGB of live trees on forest conditions (rFIA::biomass, byPlot, component "AG", landType "forest")
# grouped by the live canopy cover recorded for each forest condition (LIVE_CANOPY_CVR_PCT); only conditions with
# canopy cover > 10% and plots measured in the reference years are used. Plots are assigned to the hexagon pieces
# (study hexagons split by ecological province, script 01_study_area/02).
# Within each piece, the observed canopy-cover values are grouped into intervals: sorted values that differ by
# less than 3 percentage points share an interval; interval limits lie half-way between neighbouring interval
# means, with the lowest starting at 10% and the highest ending at 100%. The AGB of an interval is the mean
# AGB of its plot records.
#
# Usage: Rscript 02_reference/01_fia_canopy_intervals.R [first_year last_year]   (default: 2018 2022)
# Outputs (output/02_reference/):
#   reference_pieces.gpkg                 study-hexagon pieces with their id FIDP (= FID or FID_province)
#   canopy_intervals_<years>.csv          FIDP, group, lower, upper, BIO_Mg_ha (mean AGB of the interval)
#   reference_plots_<years>.csv           one row per plot and hexagon: FID, PLT_CN, BIO_Mg_ha, canopy cover
suppressPackageStartupMessages({ library(rFIA); library(DBI); library(RSQLite) })
source("R/setup.R")

args  <- commandArgs(TRUE)
years <- if (length(args) == 2) as.integer(args) else SET$reference_years
tag   <- paste(years, collapse = "_")
thr   <- SET$forest_canopy_threshold

# study-hexagon pieces
study  <- unique(fread(out("01_study_area", "study_hexagons.csv"))$FID)
pieces <- vect(out("01_study_area", "hexagon_province_pieces.gpkg"))
pieces <- pieces[pieces$FID %in% study]
whole  <- is.na(pieces$PROVINCE_N) | pieces$PROVINCE_N == ""
pieces$FIDP <- ifelse(whole, as.character(pieces$FID), paste0(pieces$FID, "_", pieces$PROVINCE_N))
writeVector(pieces[, c("FID", "FIDP")], out("02_reference", "reference_pieces.gpkg"), overwrite = TRUE, options = "FID=gpkg_fid")
msg("study hexagons:", length(study), "| pieces:", length(pieces))

# FIA tables, restricted to the states that hold plots in the study pieces (plot-level values do not depend on
# other states)
b   <- SET$conus_bbox
con <- dbConnect(SQLite(), inp("fiadb"))
pl  <- as.data.table(dbGetQuery(con, sprintf(
  "SELECT CN, STATECD, LAT, LON FROM PLOT WHERE MEASYEAR BETWEEN %d AND %d AND LAT BETWEEN %f AND %f AND LON BETWEEN %f AND %f",
  years[1] - 1, years[2] + 1, b[3], b[4], b[1], b[2])))
hit <- extract(project(pieces[, "FIDP"], "EPSG:4326"), vect(pl, geom = c("LON", "LAT"), crs = "EPSG:4326"))
states <- sort(unique(pl$STATECD[hit$id.y[!is.na(hit$FIDP)]]))
tables <- c("PLOT", "TREE", "COND", "POP_PLOT_STRATUM_ASSGN", "POP_ESTN_UNIT", "POP_EVAL",
            "POP_STRATUM", "POP_EVAL_TYP", "POP_EVAL_GRP", "PLOTGEOM")
fia <- lapply(tables, function(tb) {
  cols <- toupper(dbListFields(con, tb))
  q <- if ("STATECD" %in% cols) sprintf("SELECT * FROM %s WHERE STATECD IN (%s)", tb, paste(states, collapse = ","))
       else sprintf("SELECT * FROM %s", tb)
  dplyr::rename_with(as.data.table(dbGetQuery(con, q)), toupper)
})
names(fia) <- tables
dbDisconnect(con)
fia <- rFIA:::handleWY(fia)
class(fia) <- "FIA.Database"
msg("FIA states:", paste(states, collapse = " "))

# plot AGB by condition canopy cover
ag <- biomass(fia, byPlot = TRUE, component = "AG", landType = "forest", totals = TRUE,
              nCores = SET$workers, grpBy = "LIVE_CANOPY_CVR_PCT") |> as.data.table()
ag <- ag[between(YEAR, years[1], years[2]) & LIVE_CANOPY_CVR_PCT > thr]
ag[, BIO_Mg_ha := BIO_ACRE * TONS_ACRE_TO_MG_HA]

pos <- unique(ag[, .(PLT_CN)])[as.data.table(fia$PLOT)[, .(PLT_CN = CN, LAT, LON)], on = "PLT_CN", nomatch = 0]
pos <- pos[LAT >= b[3] & LAT <= b[4] & LON >= b[1] & LON <= b[2]]
e   <- extract(project(pieces[, "FIDP"], "EPSG:4326"), vect(pos, geom = c("LON", "LAT"), crs = "EPSG:4326"))
plot_piece <- data.table(PLT_CN = pos$PLT_CN[e$id.y], FIDP = e$FIDP)[!is.na(FIDP)]
ag <- ag[plot_piece, on = "PLT_CN", nomatch = 0]

# canopy-cover intervals per piece
vals <- ag[, .(cvr = sort(unique(LIVE_CANOPY_CVR_PCT))), by = FIDP]
vals[, group := cumsum(c(0, diff(cvr) >= SET$canopy_group_gap)), by = FIDP]
iv <- vals[, .(mean_cvr = mean(cvr)), by = .(FIDP, group)][order(FIDP, mean_cvr)]
iv[, prev := shift(mean_cvr, fill = thr), by = FIDP]
iv[, nxt  := shift(mean_cvr, type = "lead", fill = 100), by = FIDP]
iv[, `:=`(lower = prev + (mean_cvr - prev) / 2, upper = nxt - (nxt - mean_cvr) / 2)]
iv[, lower := ifelse(.I == min(.I), thr, lower), by = FIDP]
iv[, upper := ifelse(.I == max(.I), 100, upper), by = FIDP]
iv[, lower := ifelse(floor(lower) == lower, lower + 1, lower)]     # integer limits belong to the interval below
grp_agb <- merge(ag, vals, by.x = c("FIDP", "LIVE_CANOPY_CVR_PCT"), by.y = c("FIDP", "cvr"))[
  , .(BIO_Mg_ha = mean(BIO_Mg_ha)), by = .(FIDP, group)]
iv <- merge(iv[, .(FIDP, group, lower, upper)], grp_agb, by = c("FIDP", "group"))
fwrite(iv, out("02_reference", paste0("canopy_intervals_", tag, ".csv")))

# plot-level AGB per hexagon (for plot counts and the scale sensitivity)
plots <- ag[, .(BIO_Mg_ha = mean(BIO_Mg_ha), canopy = mean(LIVE_CANOPY_CVR_PCT), YEAR = YEAR[1]), by = .(PLT_CN, FIDP)]
plots[, FID := as.integer(tstrsplit(FIDP, "_", fixed = TRUE)[[1]])]
plots <- unique(plots, by = c("PLT_CN", "FID"))
fwrite(plots[, .(FID, PLT_CN = as.character(PLT_CN), YEAR, BIO_Mg_ha, canopy)],
       out("02_reference", paste0("reference_plots_", tag, ".csv")))
msg("plots:", nrow(plots), "| intervals:", nrow(iv), "| pieces with plots:", uniqueN(iv$FIDP))
