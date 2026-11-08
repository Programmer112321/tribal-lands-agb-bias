# Fig. 4 — Dominant factor of the bias per hexagon (largest |SHAP| of the bias model), SGP and NM.
# Fig. S4 — the same for all five regions, with an overview map.
#
# Usage : Rscript 06_figures_tables/fig4_dominant_factor.R
# Inputs: output/04_models/bias_main/shap_values_<P>.csv
# Output: output/06_figures_tables/fig4_dominant_factor.png, figS4_dominant_factor.png, dominant_factor_shares.csv
suppressPackageStartupMessages(library(patchwork))
source("R/setup.R")
source("R/plot_helpers.R")

FEATS <- names(FACTOR_CATEGORY)
sv <- rbindlist(lapply(c("CCI", "GEDI"), function(p) fread(out("04_models", "bias_main", paste0("shap_values_", p, ".csv")))))
sc <- paste0("SHAP_", FEATS)
sv[, top := FEATS[max.col(abs(as.matrix(.SD)), ties.method = "first")], .SDcols = sc]
sv[, top := factor(top, levels = sort(FEATS))]
sv[, product := factor(`AGB product`, levels = c("CCI", "GEDI"))]

usa <- conus_outline()
pcs <- tribal_pieces(unique(sv$FID))
mp  <- inner_join(pcs, as.data.frame(sv[, .(FID, product, top)]), by = "FID", relationship = "many-to-many")
box <- region_boxes_5070()

p_base <- ggplot(mp) +
  geom_sf(data = usa, fill = NA, inherit.aes = FALSE) +
  geom_sf(aes(fill = top), linewidth = 0.4) +
  facet_grid(product ~ ., switch = "y") +
  scale_fill_discrete(name = "Top features") +
  theme_minimal(base_size = 12, base_family = "serif") +
  theme(axis.title = element_blank(), axis.text = element_blank(), axis.ticks = element_blank(),
        panel.grid = element_blank(), strip.placement = "outside",
        strip.text.y.left = element_text(size = 12, face = "bold"),
        strip.background.y = element_rect(fill = "grey95", color = NA),
        panel.spacing = unit(2, "pt"), plot.margin = margin(1, 1, 1, 1))

# zoom on one region box; `head` = extra space above the box (share of its height) for the region label
zoom <- function(r, head = 0, label_y = 0, size = 4.2) {
  b <- box[box$region == r, ]
  h <- b$ymax - b$ymin
  p_base +
    coord_sf(xlim = c(b$xmin, b$xmax), ylim = c(b$ymin, b$ymax + head * h), expand = FALSE) +
    annotate("text", x = b$xmin, y = b$ymax + label_y * h, label = r, hjust = 0, vjust = 1, size = size,
             fontface = "bold", family = "serif")
}

fig <- zoom("SGP", 0.15, 0.11, 6.5) + zoom("NM", 0.15, 0.11, 6.5) +
  plot_layout(guides = "collect") +
  plot_annotation(tag_levels = "a", tag_prefix = "(", tag_suffix = ")") &
  theme(legend.position = "bottom", legend.title.position = "top",
        strip.text.y.left = element_text(size = 16, face = "bold", family = "serif"),
        legend.text = element_text(size = 13, family = "serif"),
        legend.title = element_text(size = 15, face = "bold", family = "serif", hjust = 0.5),
        plot.tag = element_text(size = 18, face = "bold", family = "serif"),
        plot.margin = margin(8, 3, 3, 8)) &
  guides(fill = guide_legend(nrow = 2))
save_png(fig, "fig4_dominant_factor", 9.5, 6)

figS4 <- overview_map(pcs) + zoom("PNW") + zoom("SW") + zoom("SGP") + zoom("NM") + zoom("SECP") +
  S_LAYOUT + S_ANNOT & S_THEME &
  guides(fill = guide_legend(title.position = "top", nrow = 2, byrow = TRUE,
                             keyheight = unit(5, "pt"), keywidth = unit(10, "pt")))
save_png(figS4, "figS4_dominant_factor", 8, 6)

# shares of hexagons per dominant factor (Section 3.3)
reg <- fread(out("03_predictors", "regions.csv"))[, .(FID, Region_orig)]
sh <- merge(sv[, .(FID, product, top)], reg, by = "FID")
tab <- rbind(sh[, .N, by = .(product, region = Region_orig, top)], sh[, .N, by = .(product, top)][, region := "All"])
tab[, share_pct := round(100 * N / sum(N), 1), by = .(product, region)]
fwrite(tab[order(product, region, -share_pct)], out("06_figures_tables", "dominant_factor_shares.csv"))
