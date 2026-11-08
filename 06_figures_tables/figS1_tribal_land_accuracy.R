# Fig. S1 — Accuracy per tribal land: distribution (kernel density) of R² = 1 - SSE/SST and RMSE of the satellite
# AGB against the reference over the hexagons of each tribal land (each hexagon counted for one tribal land).
#
# Usage : Rscript 06_figures_tables/figS1_tribal_land_accuracy.R
# Output: output/06_figures_tables/figS1_tribal_land_accuracy.png, tribal_land_accuracy.csv
suppressPackageStartupMessages(library(patchwork))
source("R/setup.R")
source("R/plot_helpers.R")

d <- fread(out("03_predictors", "analysis_main_main.csv"))
d[, sat := AGB + `AGB REF`]
tm <- d[, .(n = .N, R2 = 1 - sum((sat - `AGB REF`)^2) / sum((`AGB REF` - mean(`AGB REF`))^2),
            RMSE = sqrt(mean((sat - `AGB REF`)^2))), by = .(product = `AGB product`, Tribe)]
fwrite(tm[order(product, Tribe)], out("06_figures_tables", "tribal_land_accuracy.csv"))

dens <- function(col, xlab) {
  ggplot(tm, aes(.data[[col]], color = product, fill = product)) +
    geom_density(alpha = 0, linewidth = 1.1) +
    scale_color_manual(values = c(CCI = "darkblue", GEDI = "darkred"), name = NULL) +
    scale_fill_manual(values = c(CCI = "lightblue", GEDI = "lightcoral"), name = NULL) +
    labs(x = xlab, y = "Density") +
    theme_bw()
}
fig <- (dens("R2", "R²") | dens("RMSE", "RMSE(Mg/ha)")) + plot_layout(guides = "collect") &
  theme(legend.position = "top")
save_png(fig, "figS1_tribal_land_accuracy", 8, 4)
print(tm[, .(tribal_lands = .N, R2_median = median(R2), share_R2_above_0 = mean(R2 > 0),
             RMSE_median = median(RMSE), RMSE_min = min(RMSE), RMSE_max = max(RMSE)), by = product])
