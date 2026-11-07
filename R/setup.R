# Shared setup for all R scripts. Run scripts from the repository root, e.g.
#   Rscript 01_study_area/01_fia_plot_agb.R
suppressPackageStartupMessages({
  library(yaml)
  library(data.table)
  library(terra)
})

ROOT <- normalizePath(getwd(), winslash = "/")
if (!file.exists(file.path(ROOT, "config.yml"))) stop("Run the scripts from the repository root (config.yml not found).")
CFG <- yaml::read_yaml(file.path(ROOT, "config.yml"))
SET <- lapply(CFG$settings, function(v) if (is.list(v)) unlist(v) else v)   # yaml lists -> vectors

is_abs <- function(p) grepl("^([A-Za-z]:|/|\\\\)", p)

# path of a raw input listed in config.yml
inp <- function(key) {
  p <- CFG$inputs[[key]]
  if (is.null(p)) stop("config.yml has no input '", key, "'")
  p <- if (is_abs(p)) p else file.path(CFG$input_dir, p)
  if (!file.exists(p)) stop("input not found: ", p)
  p
}

# path of an output (or intermediate) file; creates the folder
out <- function(...) {
  base <- if (is_abs(CFG$output_dir)) CFG$output_dir else file.path(ROOT, CFG$output_dir)
  f <- file.path(base, ...)
  dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
  f
}

# short tons per acre (rFIA BIO_ACRE) -> Mg per hectare
TONS_ACRE_TO_MG_HA <- 0.90718474 * 2.47105381   # = 2.2417

msg <- function(...) cat(format(Sys.time(), "%H:%M:%S"), "|", ..., "\n")
