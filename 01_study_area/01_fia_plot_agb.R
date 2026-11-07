# 01 — Plot-level forest aboveground biomass from FIA (rFIA)
#
# rFIA::biomass(byPlot = TRUE, component = "AG", landType = "forest") on the whole FIA database:
# aboveground dry biomass of live trees on forest land, one row per plot measurement.
# YEAR is the measurement year. Rows for 2018-2023 are kept; later steps use
#   2019-2023  plot counts for the hexagon selection (Section 2.1),
#   2018-2022  plots for the hexagon x ecological-province pieces and the reference AGB (Section 2.3).
#
# Output: output/01_study_area/fia_plot_agb_2018_2023.csv
#   PLT_CN, pltID, YEAR, BIO_ACRE (short tons/acre), BIO_Mg_ha, PROP_FOREST, LAT, LON
suppressPackageStartupMessages({ library(rFIA); library(DBI); library(RSQLite) })
source("R/setup.R")

n_cores <- max(1, floor(parallel::detectCores() * 0.75))

con <- dbConnect(SQLite(), inp("fiadb"))
tables <- c("PLOT", "TREE", "COND", "POP_PLOT_STRATUM_ASSGN", "POP_ESTN_UNIT", "POP_EVAL",
            "POP_STRATUM", "POP_EVAL_TYP", "POP_EVAL_GRP", "PLOTGEOM")
fia <- lapply(tables, function(tb) dplyr::rename_with(as.data.table(dbReadTable(con, tb)), toupper))
names(fia) <- tables
dbDisconnect(con)
fia <- rFIA:::handleWY(fia)          # as rFIA::readFIA does for Wyoming
class(fia) <- "FIA.Database"
msg("FIA tables read")

plot_ag <- biomass(fia, byPlot = TRUE, component = "AG", landType = "forest",
                   totals = TRUE, nCores = n_cores) |> as.data.table()
plot_ag <- plot_ag[between(YEAR, 2018, 2023)]
plot_ag <- merge(plot_ag, as.data.table(fia$PLOT)[, .(PLT_CN = CN, LAT, LON)], by = "PLT_CN", all.x = TRUE)
plot_ag[, BIO_Mg_ha := BIO_ACRE * TONS_ACRE_TO_MG_HA]

fwrite(plot_ag[, .(PLT_CN = as.character(PLT_CN), pltID, YEAR, BIO_ACRE, BIO_Mg_ha, PROP_FOREST, LAT, LON)],
       out("01_study_area", "fia_plot_agb_2018_2023.csv"))
msg("plot measurements 2018-2023:", nrow(plot_ag))
