# 03 — Forest age per hexagon from TreeMap 2020 (Section 2.4)
#
# TreeMap 2020 assigns an FIA plot to every 30-m forest pixel. Each pixel gets the stand age (FIADB COND.STDAGE)
# of its plot's forest condition, moved to 2020: age = STDAGE + (2020 - MEASYEAR). (Two plots measured after
# 2020 give -1 and -2; these are stored as 0, as in the 16-bit unsigned raster used for the paper.)
# Forest age = mean (and SD) over the pixels of the hexagon part that lies inside tribal lands.
#
# Usage : Rscript 03_predictors/03_treemap_stand_age.R
# Inputs: TreeMap 2020 raster with its attribute table (config: treemap_2020), FIADB, study hexagons
# Output: output/03_predictors/treemap_stand_age.csv  (FID, Forest age, Forest age SD)
suppressPackageStartupMessages({ library(DBI); library(RSQLite); library(future.apply) })
source("R/setup.R")

TM   <- inp("treemap_2020")
fids <- sort(unique(fread(out("01_study_area", "study_hexagons.csv"))$FID))

# plot -> stand age lookup
rat <- as.data.table(cats(rast(TM))[[1]])[, .(Value, PLT_CN = sprintf("%.0f", PLT_CN))]
con <- dbConnect(SQLite(), inp("fiadb"))
dbWriteTable(con, "tm_plt", data.frame(PLT_CN = rat$PLT_CN), temporary = TRUE, overwrite = TRUE)
age <- as.data.table(dbGetQuery(con, "
  SELECT CAST(p.CN AS TEXT) AS PLT_CN, p.MEASYEAR, c.STDAGE
  FROM PLOT p JOIN tm_plt t ON CAST(p.CN AS TEXT) = t.PLT_CN
  JOIN COND c ON c.PLT_CN = p.CN AND c.COND_STATUS_CD = 1"))
dbDisconnect(con)
lut <- merge(rat, age, by = "PLT_CN")[!is.na(STDAGE)]
stopifnot(!anyDuplicated(lut$Value))                       # one forest condition per TreeMap plot
lut[, age := pmax(STDAGE + (SET$treemap_age_year - MEASYEAR), 0)]
LUT <- as.matrix(lut[, .(Value, age)])
msg("lookup:", nrow(lut), "plots with a stand age")

# hexagon parts inside tribal lands, dissolved per hexagon
PIECES <- out("01_study_area", "tribal_land_hexagon_pieces.gpkg")

one_hex <- function(fid) {
  suppressPackageStartupMessages({ library(terra); library(data.table) })
  terraOptions(progress = 0, memfrac = 0.05)
  r <- rast(TM)
  p <- vect(PIECES); p <- project(aggregate(p[p$FID == fid, ], by = "FID"), crs(r))
  x <- crop(r, p, snap = "out")
  levels(x) <- NULL
  a <- classify(x, LUT, others = NA)
  data.table(FID = fid,
             `Forest age`    = extract(a, p, fun = mean, na.rm = TRUE, ID = FALSE)[[1]],
             `Forest age SD` = extract(a, p, fun = sd,   na.rm = TRUE, ID = FALSE)[[1]])
}

plan(multisession, workers = SET$workers)
res <- rbindlist(future_lapply(fids, one_hex, future.seed = TRUE))
plan(sequential)
fwrite(res[order(FID)], out("03_predictors", "treemap_stand_age.csv"))
msg("TreeMap stand age:", nrow(res), "hexagons; missing:", sum(is.na(res$`Forest age`)))
