# Fig. 2 — (a) satellite vs reference AGB per hexagon (R² = squared Pearson r, RMSE, least-squares line, 1:1 line);
#          (b) bias (satellite - reference) mapped for the SGP and NM regions.
# Fig. S2 — (a) the five study regions; (b)-(f) bias maps for each region (as panel b of Fig. 2).
#
# Usage : Rscript 06_figures_tables/fig2_accuracy_and_bias.R
# Output: output/06_figures_tables/fig2_accuracy_and_bias.png, figS2_bias_maps.png
suppressPackageStartupMessages({ library(patchwork); library(purrr) })
source("R/setup.R")
source("R/plot_helpers.R")

d <- fread(out("03_predictors", "analysis_main_main.csv"))
d[, sat := AGB + `AGB REF`]
d[, product := factor(`AGB product`, levels = c("CCI", "GEDI"))]

# (a) scatter
met <- d[, .(R2 = cor(`AGB REF`, sat)^2, RMSE = sqrt(mean((sat - `AGB REF`)^2))), by = product]
axis_max <- max(c(d$`AGB REF`, d$sat))
fit <- d[, as.list(coef(lm(sat ~ `AGB REF`))), by = product]
setnames(fit, c("product", "intercept", "slope"))
fit[, `:=`(x = 0.55 * axis_max, angle = atan(slope) * 180 / pi,
           label = sprintf("y = %.2fx %s %.1f", slope, ifelse(intercept < 0, "−", "+"), abs(intercept)))]
fit[, y := intercept + slope * x]
one <- data.table(product = factor(c("CCI", "GEDI")), x = 0.85 * axis_max, y = 0.85 * axis_max)

p_a <- ggplot(d, aes(`AGB REF`, sat, color = product)) +
  geom_point(alpha = 0.6, size = 1.2) +
  geom_abline(intercept = 0, slope = 1, linetype = "dashed", linewidth = 0.7) +
  geom_smooth(method = "lm", formula = y ~ x, se = FALSE, linewidth = 0.8, color = "black") +
  facet_wrap(~product) +
  scale_color_manual(values = PRODUCT_COLORS) +
  geom_text(data = met, aes(x = -Inf, y = Inf, label = sprintf("R² = %.2f\nRMSE = %.2f", R2, RMSE)),
            hjust = -0.1, vjust = 1.2, size = 4.2, family = "serif", inherit.aes = FALSE) +
  geom_label(data = fit, aes(x, y, label = label, angle = angle), vjust = -0.4, size = 3.6, family = "serif",
             fill = scales::alpha("white", 0.85), linewidth = 0, label.padding = unit(0.1, "lines"),
             inherit.aes = FALSE) +
  geom_text(data = one, aes(x, y), label = "1:1", angle = 45, vjust = 1.5, size = 3.6, family = "serif",
            inherit.aes = FALSE) +
  labs(x = "AGB Reference (Mg/ha)", y = "AGB Product (Mg/ha)") +
  coord_equal() +
  theme_bw(base_size = 12, base_family = "serif") +
  theme(strip.text = element_text(face = "bold", size = 12), legend.position = "none")

# (b) bias maps
pcs <- tribal_pieces(unique(d$FID)) |> st_simplify(dTolerance = 2000, preserveTopology = TRUE)
mp  <- inner_join(pcs, as.data.frame(d[, .(FID, product, AGB)]), by = "FID", relationship = "many-to-many")
lim <- ceiling(max(abs(d$AGB)) / 10) * 10
box <- region_boxes_5070()
usa <- conus_outline()

zoom_map <- function(r) {
  b <- box[box$region == r, ]
  ggplot(mp) +
    geom_sf(data = usa, fill = NA, color = "gray60", linewidth = 0.1, inherit.aes = FALSE) +
    geom_sf(aes(fill = AGB), color = NA) +
    scale_fill_gradient2(low = "#4575b4", mid = "#fcfdbf", high = "#ff0000", midpoint = 0, limits = c(-lim, lim),
                         oob = scales::squish, name = "AGB Bias (Mg/ha)") +
    facet_grid(product ~ ., switch = "y") +
    coord_sf(xlim = c(b$xmin, b$xmax), ylim = c(b$ymin, b$ymax), expand = FALSE) +
    annotate("text", x = b$xmin, y = b$ymax, label = r, hjust = 0, vjust = 1, size = 4.2, fontface = "bold",
             family = "serif") +
    theme_minimal(base_size = 12, base_family = "serif") +
    theme(axis.title = element_blank(), axis.text = element_blank(), panel.grid = element_blank(),
          strip.placement = "outside", strip.text.y.left = element_text(size = 12, face = "bold"),
          strip.background.y = element_rect(fill = "grey95", color = NA), panel.spacing = unit(2, "pt"),
          plot.margin = margin(1, 1, 1, 1)) +
    guides(fill = guide_colorbar(direction = "horizontal", title.position = "top", barheight = unit(6, "pt"),
                                 barwidth = unit(90, "pt"), ticks = FALSE))
}

p_b <- zoom_map("SGP") + zoom_map("NM") + plot_layout(guides = "collect") & theme(legend.position = "bottom")
fig <- p_a / p_b + plot_layout(heights = c(1, 1.5)) +
  plot_annotation(tag_levels = list(c("(a)", "(b)"))) &
  theme(plot.tag = element_text(size = 13, face = "bold", family = "serif"))
save_png(fig, "fig2_accuracy_and_bias", 6.5, 8.5)

# Fig. S2: overview map (a) and the five regions (b-f), small-panel style
s2_map <- function(r) {
  b <- box[box$region == r, ]
  ggplot(mp) +
    geom_sf(data = usa, fill = NA, color = "gray60", inherit.aes = FALSE) +
    geom_sf(aes(fill = AGB), color = NA) +
    scale_fill_gradient2(low = "#4575b4", mid = "#fcfdbf", high = "#ff0000", midpoint = 0, limits = c(-lim, lim),
                         oob = scales::squish, name = "AGB Bias (Mg/ha)") +
    facet_grid(product ~ ., switch = "y") +
    coord_sf(xlim = c(b$xmin, b$xmax), ylim = c(b$ymin, b$ymax), expand = FALSE) +
    annotate("text", x = b$xmin, y = b$ymax, label = r, hjust = 0, vjust = 1, size = 4.2, fontface = "bold",
             family = "serif") +
    theme_minimal(base_size = 9) +
    theme(axis.title = element_blank(), axis.text = element_blank(), axis.ticks = element_blank(),
          panel.grid = element_blank(), strip.placement = "outside",
          strip.text.y.left = element_text(size = 7, face = "bold"),
          strip.background.y = element_rect(fill = "grey95", color = NA), panel.spacing = unit(2, "pt"),
          plot.margin = margin(1, 1, 1, 1)) +
    guides(fill = guide_colorbar(direction = "horizontal", title.position = "top", barheight = unit(5, "pt"),
                                 barwidth = unit(80, "pt"), ticks = FALSE))
}
figS2 <- overview_map(tribal_pieces(unique(d$FID))) + s2_map("PNW") + s2_map("SW") + s2_map("SGP") + s2_map("NM") +
  s2_map("SECP") + S_LAYOUT + S_ANNOT & S_THEME
save_png(figS2, "figS2_bias_maps", 8, 6)
