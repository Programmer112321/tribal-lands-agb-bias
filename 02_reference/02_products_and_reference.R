# 02 — Forest mask, satellite AGB and product-matched reference AGB per hexagon (Sections 2.1 and 2.3)
#
# For each hexagon piece and product (GEDI L4B 1-km cells; CCI 100-m cells):
#   forest mask   a product cell is retained when the mean NLCD 2020 tree canopy cover of the 30-m pixels inside it
#                 is > 10% and the product has a value (NLCD codes > 100 count as 0 in this mean);
#   satellite     mean product AGB (and uncertainty layer) over the retained cells, each cell weighted by the
#                 fraction of it inside the piece; pieces of a hexagon are combined with the same weights;
#   reference     every 30-m NLCD pixel inside the retained cells gets the FIA AGB of its canopy-cover interval
#                 (script 01); pixels with canopy cover <= 10% get 0. The piece reference is the mean over these
#                 pixels, and the hexagon reference is the mean of its pieces.
#
# Usage: Rscript 02_reference/02_products_and_reference.R [first_year last_year cci_year]   (default 2018 2022 2020)
# Output: output/02_reference/products_reference_<years>_cci<year>.csv
#   FID, product, sat (Mg/ha), unc (GEDI: standard error; CCI: standard deviation), ref (Mg/ha), n_cells
suppressPackageStartupMessages({ library(sf); library(exactextractr); library(future.apply) })
source("R/setup.R")

args     <- commandArgs(TRUE)
years    <- if (length(args) >= 2) as.integer(args[1:2]) else SET$reference_years
cci_year <- if (length(args) == 3) args[3] else "2020"
tag      <- paste(years, collapse = "_")
thr      <- SET$forest_canopy_threshold

PIECES <- out("02_reference", "reference_pieces.gpkg")
TCC    <- inp("nlcd_tcc_2020")
PROD   <- list(GEDI = c(inp("gedi_l4b_mu"), inp("gedi_l4b_se")), CCI = inp(paste0("cci_", cci_year)))
ids    <- vect(PIECES)$FIDP

one_piece <- function(fidp) {
  suppressPackageStartupMessages({ library(terra); library(sf); library(exactextractr); library(data.table) })
  terraOptions(progress = 0, memfrac = 0.05)
  h   <- vect(PIECES); h <- h[h$FIDP == fidp, ]
  tr  <- rast(TCC)
  tcr <- crop(tr, buffer(project(h, crs(tr)), 3000), snap = "out")
  tna <- ifel(tcr > 101, NA, tcr)          # canopy cover for the reference (codes > 100 = no data)
  t0  <- ifel(tcr > 101, 0, tcr)           # canopy cover for the mask
  hs  <- st_as_sf(project(h, crs(tr)))
  res <- list()
  for (p in names(PROD)) {
    pr <- if (p == "GEDI") rast(PROD$GEDI) else rast(PROD$CCI)[[c("agb", "agb_sd")]]
    names(pr) <- c("agb", "unc")
    hp <- project(h, crs(pr))
    pc <- crop(pr, buffer(hp, 3 * res(pr)[1] * ifelse(is.lonlat(pr), 111000, 1)), snap = "out")
    cell_tcc <- project(t0, pc[[1]], method = "average")             # mean canopy cover of each product cell
    keep <- ifel(cell_tcc > thr & !is.na(pc[[1]]), 1, NA)
    x <- exact_extract(c(pc, keep), st_as_sf(hp), progress = FALSE)[[1]]
    names(x)[1:3] <- c("agb", "unc", "keep")
    x <- x[!is.na(x$keep) & !is.na(x$agb), ]
    k30 <- project(keep, tna, method = "near")                        # 30-m pixel inherits its cell's flag
    v <- exact_extract(mask(tna, k30), hs, progress = FALSE)[[1]]$value
    v <- suppressWarnings(as.numeric(as.character(v))); tb <- table(v[!is.na(v)])
    res[[p]] <- list(
      sat = data.table(FIDP = fidp, product = p, w = sum(x$coverage_fraction),
                       agb_w = sum(x$agb * x$coverage_fraction), unc_w = sum(x$unc * x$coverage_fraction, na.rm = TRUE)),
      pix = if (length(tb)) data.table(FIDP = fidp, product = p, tcc = as.numeric(names(tb)), n = as.numeric(tb)))
  }
  list(sat = rbindlist(lapply(res, `[[`, "sat")), pix = rbindlist(lapply(res, `[[`, "pix")))
}

plan(multisession, workers = SET$workers)
r <- future_lapply(ids, function(f) tryCatch(one_piece(f), error = function(e) { message("piece ", f, ": ", conditionMessage(e)); NULL }),
                   future.seed = TRUE)
plan(sequential)
sat <- rbindlist(lapply(r, `[[`, "sat")); pix <- rbindlist(lapply(r, `[[`, "pix"))
if (uniqueN(sat$FIDP) < length(ids)) stop("pieces failed: ", length(ids) - uniqueN(sat$FIDP))
fid_of <- function(x) as.integer(tstrsplit(x, "_", fixed = TRUE)[[1]])

# satellite hexagon means
sat <- sat[, .(sat = sum(agb_w) / sum(w), unc = sum(unc_w) / sum(w), n_cells = sum(w)), by = .(FID = fid_of(FIDP), product)]

# reference: pixel counts -> interval shares -> AGB; pixels outside every interval (<= 10%) carry 0
iv  <- fread(out("02_reference", paste0("canopy_intervals_", tag, ".csv")))
ref <- iv[pix, on = .(FIDP, lower <= tcc, upper >= tcc), .(FIDP = i.FIDP, product = i.product, n = i.n, BIO_Mg_ha = x.BIO_Mg_ha)]
ref <- ref[, .(ref = sum(n * fifelse(is.na(BIO_Mg_ha), 0, BIO_Mg_ha)) / sum(n), n_pixels = sum(n)), by = .(FIDP, product)]
ref[, has_fia_plots := FIDP %in% iv$FIDP]     # pieces without FIA plots have no intervals, so their reference is 0
fwrite(ref, out("02_reference", sprintf("reference_pieces_%s_cci%s.csv", tag, cci_year)))
ref <- ref[, .(ref = mean(ref)), by = .(FID = fid_of(FIDP), product)]

res <- merge(sat, ref, by = c("FID", "product"), all = TRUE)
res[n_cells == 0, `:=`(sat = NA, unc = NA, ref = NA)]                  # no retained cell: hexagon dropped
fwrite(res[order(product, FID)], out("02_reference", sprintf("products_reference_%s_cci%s.csv", tag, cci_year)))
print(res[!is.na(sat), .(hexagons = .N, mean_sat = mean(sat), mean_ref = mean(ref), bias = mean(sat - ref),
                         RMSE = sqrt(mean((sat - ref)^2)), r2 = cor(sat, ref)^2), by = product])
