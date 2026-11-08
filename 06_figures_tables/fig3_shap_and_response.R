# Fig. 3 — Bias model: (a, b) mean |SHAP| of the ten predictors per product, with the CV R² of the model;
#          (c-e) response curves of the three predictors with the largest summed importance (both products).
# (Fig. S3, the response curves of all ten predictors, is drawn by figS3_response_curves.py.)
#
# Usage : Rscript 06_figures_tables/fig3_shap_and_response.R
# Inputs: output/04_models/bias_main/ (metrics.csv, shap_importance_<P>.csv, response_curves_<P>.csv)
# Output: output/06_figures_tables/fig3_shap_and_response.png
suppressPackageStartupMessages(library(patchwork))
source("R/setup.R")
source("R/plot_helpers.R")

B   <- function(f) out("04_models", "bias_main", f)
met <- fread(B("metrics.csv"))
imp <- rbindlist(lapply(c("CCI", "GEDI"), function(p) fread(B(paste0("shap_importance_", p, ".csv")))[, product := p]))
rc  <- rbindlist(lapply(c("CCI", "GEDI"), function(p) fread(B(paste0("response_curves_", p, ".csv")))[, product := p]))
imp[, category := FACTOR_CATEGORY[feature]]

XLAB <- list("Canopy height" = "Canopy height (m)", "Forest age" = "Forest age (years)",
             "Soil moisture" = expression("Soil moisture (m"^3 ~ "m"^{-3} * ")"),
             "AWC" = expression("AWC (mm m"^{-1} * ")"),
             "Stand density" = expression(atop("Stand density", "(SDI, trees ac"^{-1} * ")")),
             "Wood density" = expression("Wood density (g cm"^{-3} * ")"),
             "Structural diversity" = expression(atop("Structural diversity", "(WSCI, unitless)")),
             "Elevation" = "Elevation (m)", "Slope" = "Slope (degree)", "Northness" = "Northness (unitless)")

theme_imp <- theme_minimal(base_size = 12, base_family = "serif") +
  theme(legend.position = "none", legend.title = element_blank(),
        axis.title.x = element_text(face = "bold", size = 12), axis.text.x = element_text(size = 10),
        axis.text.y = element_text(face = "bold", size = 10), panel.grid.major.y = element_blank(),
        plot.margin = margin(4, 6, 4, 4), plot.title = element_text(size = 12, face = "bold", hjust = 0.5))
theme_curve <- theme_bw(base_size = 12, base_family = "serif") +
  theme(panel.grid.minor = element_blank(), panel.grid.major = element_line(color = "grey92", linewidth = 0.3),
        panel.border = element_rect(color = "grey30", fill = NA, linewidth = 0.4),
        axis.title.x = element_text(margin = margin(t = 5), size = 12, face = "plain"),
        axis.title.y = element_text(margin = margin(r = 2), size = 12),
        axis.text = element_text(color = "grey20", size = 10), legend.position = "none",
        plot.margin = margin(4, 6, 4, 4))

bar <- function(p) {
  d <- imp[product == p][order(mean_abs_shap)]
  d[, feature := factor(feature, levels = feature)]
  ggplot(d, aes(mean_abs_shap, feature, fill = category)) +
    geom_col(alpha = 0.85, color = "black", linewidth = 0.3) +
    scale_fill_manual(values = CATEGORY_COLORS[c("Abiotic", "Biotic")]) +
    labs(title = sprintf("%s  (R² = %.2f)", p, met[product == p, cv_r2]),
         x = expression(bold("Mean |SHAP Value| (Mg ha"^{-1} * ")")), y = NULL) +
    theme_imp
}

curve <- function(f, first) {
  ggplot(rc[feature == f], aes(value, predicted_bias, color = product, linetype = product)) +
    geom_line(linewidth = 0.7, alpha = 0.9) +
    scale_color_manual(values = PRODUCT_COLORS) +
    scale_linetype_manual(values = c(GEDI = "solid", CCI = "dashed")) +
    scale_x_continuous(labels = scales::label_number(big.mark = "")) +
    scale_y_continuous(labels = scales::label_number(accuracy = 1)) +
    labs(x = XLAB[[f]], y = if (first) expression(atop("Predicted AGB bias", "(Mg ha"^{-1} * ")")) else NULL,
         color = NULL, linetype = NULL) +
    theme_curve
}

top3 <- imp[, .(s = sum(mean_abs_shap)), by = feature][order(-s), feature][1:3]
pa <- bar("CCI") +
  theme(legend.position = "inside", legend.position.inside = c(0.98, 0.03), legend.justification = c(1, 0),
        legend.text = element_text(size = 10), legend.key.size = unit(0.45, "cm"),
        legend.background = element_rect(fill = "white", colour = NA))
pc <- curve(top3[1], TRUE) +
  theme(legend.position = "inside", legend.position.inside = c(0.99, 0.5), legend.justification = c(1, 0.5),
        legend.key.width = unit(0.55, "cm"), legend.key.height = unit(0.32, "cm"),
        legend.key.spacing.x = unit(0.1, "cm"), legend.margin = margin(1, 2, 1, 2),
        legend.text = element_text(size = 9.5), legend.background = element_rect(fill = NA, colour = NA))
fig <- (pa | bar("GEDI")) / free(pc | curve(top3[2], FALSE) | curve(top3[3], FALSE)) +
  plot_layout(heights = c(1.1, 1)) +
  plot_annotation(tag_levels = "a", tag_prefix = "(", tag_suffix = ")") &
  theme(plot.tag = element_text(size = 13, face = "bold", family = "serif"))
save_png(fig, "fig3_shap_and_response", 8, 6.5)
