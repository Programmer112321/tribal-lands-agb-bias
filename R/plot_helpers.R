# Shared objects for the map figures (stage 06). Source after R/setup.R.
suppressPackageStartupMessages({
  library(sf); library(ggplot2); library(dplyr); library(patchwork); library(rnaturalearth); library(rnaturalearthdata)
})
sf_use_s2(FALSE)

FIGDIR <- dirname(out("06_figures_tables", "x"))
REGION_NAMES <- c(PNW = "Pacific Northwest (PNW)", SW = "Southwest/Four Corners (SW)",
                  SGP = "Southern Great Plains (SGP)", NM = "Northern Minnesota (NM)",
                  SECP = "Southeastern Coastal Plain (SECP)")
PRODUCT_COLORS <- c(GEDI = "darkred", CCI = "darkblue")
CATEGORY_COLORS <- c(Measurement = "#E67E22", Abiotic = "#2980B9", Biotic = "#27AE60")
FACTOR_CATEGORY <- c("Canopy height" = "Biotic", "Forest age" = "Biotic", "Stand density" = "Biotic",
                     "Wood density" = "Biotic", "Structural diversity" = "Biotic", "Soil moisture" = "Abiotic",
                     "AWC" = "Abiotic", "Elevation" = "Abiotic", "Slope" = "Abiotic", "Northness" = "Abiotic")
FACTOR_UNITS <- c("Canopy height" = "m", "Forest age" = "years", "Stand density" = "SDI",
                  "Wood density" = "g/cm³", "Structural diversity" = "WSCI", "Soil moisture" = "m³/m³",
                  "AWC" = "mm/m", "Elevation" = "m", "Slope" = "degrees", "Northness" = "unitless")

# region boxes (config: lon/lat) as the EPSG:5070 bounding box of each projected rectangle
region_boxes_5070 <- function() {
  B <- CFG$settings$regions
  do.call(rbind, lapply(names(B), function(r) {
    b  <- unlist(B[[r]])
    bb <- st_bbox(st_transform(st_as_sfc(st_bbox(c(xmin = b[1], xmax = b[2], ymin = b[3], ymax = b[4]),
                                                 crs = 4326)), 5070))
    data.frame(region = r, label = REGION_NAMES[[r]], xmin = bb[["xmin"]], xmax = bb[["xmax"]],
               ymin = bb[["ymin"]], ymax = bb[["ymax"]])
  }))
}

# conterminous US outline (Natural Earth, 1:50 m), EPSG:5070
conus_outline <- function() {
  us <- ne_countries(scale = "medium", country = "United States of America", returnclass = "sf")
  st_transform(st_crop(st_make_valid(us), xmin = -125, xmax = -66.5, ymin = 24, ymax = 49), 5070)
}

# hexagon parts inside tribal lands for the analysed hexagons (EPSG:5070), and their union per tribal land
tribal_pieces <- function(fids) {
  p <- st_read(out("01_study_area", "tribal_land_hexagon_pieces.gpkg"), quiet = TRUE)
  st_transform(p[p$FID %in% fids, ], 5070)
}
tribal_outlines <- function(pieces) {
  pieces |> group_by(tribe) |> summarise(.groups = "drop")          # sf unions the geometries per group
}

# overview map: tribal-land outlines and the five region boxes (panel (a) of Fig. S2 and Fig. S4)
overview_map <- function(pieces) {
  box <- region_boxes_5070()
  box$x_label <- (box$xmin + box$xmax) / 2
  box$y_label <- box$ymax + 0.02 * (box$ymax - box$ymin)
  ggplot() +
    geom_sf(data = conus_outline(), fill = "white", color = "gray60") +
    geom_sf(data = tribal_outlines(pieces), fill = NA, color = "black", linewidth = 0.2) +
    geom_rect(data = box, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), fill = NA, color = "black",
              linewidth = 0.7) +
    geom_segment(data = box, aes(x = xmin, xend = xmax, y = ymax, yend = ymax), color = "white", linewidth = 1) +
    geom_text(data = box, aes(x = x_label + 1000, y = y_label + 10000, label = label), size = 2, fontface = "bold") +
    coord_sf(expand = FALSE) +
    theme_void(base_size = 12) +
    theme(plot.margin = margin(0, 0, 0, 0), legend.position = "none")
}

# patchwork settings shared by Fig. S2 and Fig. S4 (overview + five regions, 2 x 6 grid, legend at the bottom)
S_LAYOUT <- plot_layout(design = "AAAABC\nDDEEFF", guides = "collect", heights = c(1, 1), widths = rep(1, 6))
S_ANNOT  <- plot_annotation(theme = theme(plot.margin = margin(2, 2, 2, 2)), tag_levels = "a", tag_prefix = "(",
                            tag_suffix = ")")
S_THEME  <- theme(legend.position = "bottom", legend.title = element_text(size = 9, face = "bold"),
                  legend.text = element_text(size = 8), legend.box.margin = margin(t = -2, r = 0, b = 0, l = 0),
                  plot.tag = element_text(size = 13, face = "bold", family = "serif"))

save_png <- function(plot, name, width, height) {
  f <- file.path(FIGDIR, paste0(name, ".png"))
  ggsave(f, plot, width = width, height = height, units = "in", dpi = 600, bg = "white")
  msg("saved", f)
}
