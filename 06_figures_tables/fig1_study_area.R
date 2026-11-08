# Fig. 1 — Study area: analysed hexagons on tribal lands, coloured by the product-independent reference AGB
# (02_reference/03_forest_area_reference.R), with the five study regions.
#
# Usage : Rscript 06_figures_tables/fig1_study_area.R
# Output: output/06_figures_tables/fig1_study_area.png
source("R/setup.R")
source("R/plot_helpers.R")

fids <- unique(fread(out("03_predictors", "analysis_main_main.csv"))$FID)
ref  <- fread(out("02_reference", "forest_area_reference_2018_2022.csv"))
pcs  <- tribal_pieces(fids) |> left_join(ref[, .(FID, ref_forest_area)], by = "FID")
box  <- region_boxes_5070()
box$x_label <- (box$xmin + box$xmax) / 2
box$y_label <- box$ymax + 0.02 * (box$ymax - box$ymin)

p <- ggplot() +
  geom_sf(data = conus_outline(), fill = "white", color = "gray60") +
  geom_sf(data = tribal_outlines(pcs), fill = NA, color = "black", linewidth = 0.2) +
  geom_rect(data = box, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), fill = NA, color = "black",
            linewidth = 0.7) +
  geom_segment(data = box, aes(x = xmin, xend = xmax, y = ymax, yend = ymax), color = "white", linewidth = 1) +
  geom_text(data = box, aes(x = x_label, y = y_label + 10000, label = label), size = 3, fontface = "bold") +
  geom_sf(data = pcs, aes(fill = ref_forest_area), color = NA) +
  scale_fill_viridis_c(option = "magma", direction = -1, name = "AGB (Mg/ha)") +
  coord_sf(crs = st_crs(5070), default_crs = st_crs(5070)) +
  labs(x = "", y = "") +
  theme_void(base_size = 12) +
  theme(panel.grid.major = element_line(color = "grey85", linewidth = 0.4),
        axis.text = element_text(color = "grey20"),
        legend.title = element_text(face = "bold"),
        legend.position = c(0.92, 0.28),
        legend.background = element_rect(fill = "white", color = "grey80"),
        legend.key.height = unit(1.0, "lines"))
save_png(p, "fig1_study_area", 8, 6)
