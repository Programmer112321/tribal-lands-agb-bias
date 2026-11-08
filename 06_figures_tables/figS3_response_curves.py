"""Fig. S3 - Response curves of all ten predictors (bias model, both products)

Predicted bias over the 1st-99th percentile of each predictor, other predictors at their medians (04_models/01).

Usage : python 06_figures_tables/figS3_response_curves.py
Input : output/04_models/bias_main/response_curves_<product>.csv
Output: output/06_figures_tables/figS3_response_curves.png
"""
import os
import sys

sys.path.insert(0, os.path.join(os.getcwd(), "py"))
from common import PRODUCTS, msg, out

import matplotlib
matplotlib.use("Agg")
import matplotlib.lines as mlines
import matplotlib.pyplot as plt
import pandas as pd

RC = {"font.family": "serif", "font.serif": ["Times New Roman", "DejaVu Serif", "serif"],
      "font.size": 12, "axes.titlesize": 13, "axes.labelsize": 12,
      "xtick.labelsize": 10, "ytick.labelsize": 10, "legend.fontsize": 12}
COL = {"CCI": "#2E86C1", "GEDI": "#E67E22"}
UNITS = {"Canopy height": "m", "Forest age": "years", "Stand density": "SDI, trees ac⁻¹", "Wood density": "g cm⁻³",
         "Structural diversity": "WSCI, unitless", "AWC": "mm m⁻¹", "Soil moisture": "m³ m⁻³", "Elevation": "m",
         "Slope": "°", "Northness": "unitless"}
ORDER = ["Canopy height", "Forest age", "Stand density", "Wood density", "Structural diversity", "AWC",
         "Soil moisture", "Elevation", "Slope", "Northness"]

rc = {p: pd.read_csv(out("04_models", "bias_main", f"response_curves_{p}.csv")) for p in PRODUCTS}

with plt.rc_context(RC):
    ncol = 4
    fig, axes = plt.subplots(3, ncol, figsize=(14, 9))
    axes = axes.ravel()
    for i, feat in enumerate(ORDER):
        ax = axes[i]
        for p in PRODUCTS:
            d = rc[p][rc[p].feature == feat]
            ax.plot(d.value, d.predicted_bias, color=COL[p], lw=2.2, label=p)
        ax.set_title(feat, fontweight="bold", pad=4)
        ax.set_xlabel(f"{feat} ({UNITS[feat]})")
        if i % ncol == 0:
            ax.set_ylabel("Predicted AGB bias (Mg ha⁻¹)", fontweight="bold")
        ax.grid(alpha=0.3, linestyle="--")
        ax.margins(x=0.02)
    for j in range(len(ORDER), len(axes)):
        axes[j].axis("off")
    handles = [mlines.Line2D([], [], color=COL[p], lw=2.5, label=p) for p in PRODUCTS]
    axes[len(ORDER)].legend(handles=handles, title="AGB product", loc="center", frameon=True, framealpha=0.92,
                            edgecolor="gray", fontsize=13, title_fontsize=13)
    fig.tight_layout(rect=[0, 0, 1, 0.98])
    f = out("06_figures_tables", "figS3_response_curves.png")
    fig.savefig(f, bbox_inches="tight", dpi=600)
msg("saved", f)
