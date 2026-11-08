"""Fig. 5 / Fig. S5 - Accuracy before and after correction, all hexagons and per merged region

  raw       satellite AGB vs reference AGB
  regional  out-of-fold predictions of the regional correction models (04_models/02); "All" pools the regions
  global    out-of-fold predictions of the global correction model (04_models/03)
Fig. 5:  (a) RMSE; (b) overfitting gap = out-of-fold RMSE - training RMSE (full-fit predictions).
Fig. S5: (a) R^2 = squared Pearson correlation; (b) overfitting gap = training R^2 - out-of-fold R^2
         (R^2 = 1 - SSE/SST).
Bar heights use full precision; labels are rounded once (half away from zero).

Usage : python 06_figures_tables/fig5_correction_performance.py
Output: output/06_figures_tables/fig5_correction_rmse.png, figS5_correction_r2.png, fig5_S5_metrics.csv
"""
import os
import sys
from decimal import ROUND_HALF_UP, Decimal

sys.path.insert(0, os.path.join(os.getcwd(), "py"))
from common import PRODUCTS, load_table, out

import matplotlib
matplotlib.use("Agg")
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

reg = pd.read_csv(out("03_predictors", "regions.csv"))[["FID", "Region"]]
raw = load_table(out("03_predictors", "analysis_main_main.csv")).merge(reg, on="FID")
rgn = pd.read_csv(out("04_models", "regional_main", "predictions.csv"))
glb = pd.read_csv(out("04_models", "global_main", "predictions.csv"))
SCOPES = [("All", None), ("SGP", "SGP"), ("SW+PNW", "SW"), ("NM+SECP", "NM")]
MODELS = ["raw", "regional", "global"]


def rmse(a, p):
    return float(np.sqrt(np.mean((np.asarray(a) - np.asarray(p)) ** 2)))


def r2_det(a, p):
    a, p = np.asarray(a, float), np.asarray(p, float)
    return float(1 - np.sum((a - p) ** 2) / np.sum((a - a.mean()) ** 2))


def r2_pearson(a, p):
    return float(np.corrcoef(a, p)[0, 1] ** 2)


rows = []
for prod in PRODUCTS:
    for lab, r in SCOPES:
        sel = (lambda d: d) if r is None else (lambda d, r=r: d[d["Region"] == r])
        q = sel(raw[raw["AGB product"] == prod])
        cells = {"raw": (q["AGB REF"], q["satellite_AGB"], None)}
        for m, d in [("regional", rgn), ("global", glb)]:
            q = sel(d[d["AGB product"] == prod])
            cells[m] = (q["AGB_REF_actual"], q["AGB_REF_predicted"], q["AGB_REF_pred_full"])
        for m, (a, p, f) in cells.items():
            rows.append(dict(scope=lab, product=prod, model=m, n=len(a), RMSE=rmse(a, p), R2_pearson=r2_pearson(a, p),
                             gap_RMSE=np.nan if f is None else rmse(a, p) - rmse(a, f),
                             gap_R2=np.nan if f is None else r2_det(a, f) - r2_det(a, p)))
M = pd.DataFrame(rows)
M.to_csv(out("06_figures_tables", "fig5_S5_metrics.csv"), index=False)

COLORS = {("CCI", "raw"): "#AED6F1", ("CCI", "regional"): "#5DADE2", ("CCI", "global"): "#2E86C1",
          ("GEDI", "raw"): "#FAD7A0", ("GEDI", "regional"): "#F0B27A", ("GEDI", "global"): "#E67E22"}
LABELS = {(p, m): (p if m == "raw" else f"{m.capitalize()} {p}") for p in PRODUCTS for m in MODELS}
ORDER = [(p, m) for p in PRODUCTS for m in MODELS]
W = 0.13
OFF = np.array([-2.5, -1.5, -0.5, 0.5, 1.5, 2.5]) * W
fmt = lambda v, nd: str(Decimal(repr(v)).quantize(Decimal(1).scaleb(-nd), rounding=ROUND_HALF_UP))


def panel(ax, col, nd, ylabel, title, ymax):
    xs = np.arange(len(SCOPES))
    for i, (p, m) in enumerate(ORDER):
        v = [M.loc[(M.scope == s) & (M["product"] == p) & (M.model == m), col].item() for s, _ in SCOPES]
        bars = ax.bar(xs + OFF[i], v, W, color=COLORS[(p, m)], alpha=0.9, edgecolor="black", linewidth=0.5)
        for b, val in zip(bars, v):
            if not np.isnan(val):
                ax.text(b.get_x() + b.get_width() / 2, b.get_height() + 0.015, fmt(val, nd), ha="center",
                        va="bottom", fontsize=10, fontweight="bold", rotation=90)
    ax.axvline(0.5, color="gray", linestyle="--", lw=1.2, alpha=0.6)
    ax.axhline(0, color="black", lw=0.8)
    ax.set_ylim(0, ymax)
    ax.set_xticks(xs)
    ax.set_xticklabels([s for s, _ in SCOPES], fontsize=13)
    ax.set_ylabel(ylabel, fontsize=13, fontweight="bold")
    ax.set_title(title, fontsize=13, fontweight="bold", pad=8)
    ax.grid(axis="y", alpha=0.3, linestyle="--")


def figure(spec, name):
    with plt.rc_context({"font.family": "serif", "font.serif": ["Times New Roman", "DejaVu Serif", "serif"],
                         "font.size": 12, "axes.titlesize": 13, "axes.labelsize": 13, "xtick.labelsize": 12,
                         "ytick.labelsize": 12, "legend.fontsize": 11, "mathtext.fontset": "stix"}):
        fig, ax = plt.subplots(2, 1, figsize=(9, 9), sharex=True)
        fig.subplots_adjust(hspace=0.28, bottom=0.12)
        for a, s in zip(ax, spec):
            panel(a, *s)
        handles = [mpatches.Patch(color=COLORS[k], label=LABELS[k]) for m in MODELS for k in [("GEDI", m), ("CCI", m)]]
        fig.legend(handles=handles, fontsize=12, loc="upper center", bbox_to_anchor=(0.5, 0.03), ncol=3,
                   framealpha=0.92, edgecolor="gray", handlelength=1.4, handleheight=1.0, columnspacing=1.5)
        fig.savefig(out("06_figures_tables", name), bbox_inches="tight", dpi=600)
        plt.close(fig)


figure([("RMSE", 1, "RMSE (Mg/ha)", "(a)  RMSE", M.RMSE.max() * 1.25),
        ("gap_RMSE", 1, "OOF RMSE − Train RMSE (Mg/ha)",
         "(b)  Overfitting gap  (OOF RMSE − Train RMSE; smaller = better)", M.gap_RMSE.max() * 1.25)],
       "fig5_correction_rmse.png")
figure([("R2_pearson", 2, "R²", "(a)  R²  (Pearson)", 1.10),
        ("gap_R2", 2, "Train R² − OOF R²",
         "(b)  Overfitting gap  (Train R² − OOF R²; smaller = better)", M.gap_R2.max() * 1.25)],
       "figS5_correction_r2.png")
pd.set_option("display.width", 200)
print(M.round(3).to_string(index=False))
