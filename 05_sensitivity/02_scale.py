"""05/02 - Scale sensitivity of the product accuracy (Appendix Table S2)

Accuracy of the satellite AGB against the reference at three aggregation levels:
  hexagon        the 257 hexagons;
  tribal land    mean satellite and mean reference AGB over the hexagons of each tribal land (within a region);
  well sampled   hexagons with at least 8 forested FIA plots in 2018-2022.
bias = mean(satellite - reference); RMSE; r^2 = squared Pearson correlation. Part (b): mean bias per merged region
at hexagon and tribal-land level. Also prints the FIA sampling error of the plot-mean forest AGB per hexagon
(standard error = SD of the plot AGB / sqrt(number of plots)).

Usage : python 05_sensitivity/02_scale.py
Inputs: output/03_predictors/analysis_main_main.csv, regions.csv; output/02_reference/reference_plots_2018_2022.csv
Output: output/05_sensitivity/table_S2.csv
"""
import csv
import os
import sys

sys.path.insert(0, os.path.join(os.getcwd(), "py"))
from common import PRODUCTS, load_table, msg, out

import numpy as np
import pandas as pd

d = load_table(out("03_predictors", "analysis_main_main.csv")).merge(
    pd.read_csv(out("03_predictors", "regions.csv"))[["FID", "Region"]], on="FID", how="left")
pl = pd.read_csv(out("02_reference", "reference_plots_2018_2022.csv"))
fia = pl.groupby("FID")["BIO_Mg_ha"].agg(n_plots="size", se=lambda v: v.std(ddof=1) / np.sqrt(len(v)))
d = d.merge(fia, on="FID", how="left").fillna({"n_plots": 0})
d["sat"], d["ref"] = d["satellite_AGB"], d["AGB REF"]


def acc(s, r):
    e = s - r
    return len(e), e.mean(), np.sqrt((e ** 2).mean()), np.corrcoef(s, r)[0, 1] ** 2


def tribal(q):
    return q.groupby(["Tribe", "Region"])[["sat", "ref"]].mean()


sg = lambda v: f"+{v:.1f}" if v >= 0 else f"−{abs(v):.1f}"
cell = lambda t: f"{sg(t[1])} / {t[2]:.1f} / {t[3]:.2f}"
res = {}
for p in PRODUCTS:
    q = d[d["AGB product"] == p]
    t = tribal(q)
    w = q[q["n_plots"] >= 8]
    res[p] = {"hex": acc(q.sat, q.ref), "tribe": acc(t.sat, t.ref), "well": acc(w.sat, w.ref)}
    for g in ["SGP", "SW", "NM"]:
        qq = q[q.Region == g]
        tt = tribal(qq)
        res[p][g] = (len(qq), (qq.sat - qq.ref).mean(), len(tt), (tt.sat - tt.ref).mean())
    msg(f"{p}: FIA sampling SE of the plot-mean forest AGB: median {q.se.median():.1f}, "
        f"RMS {np.sqrt((q.se.dropna() ** 2).mean()):.1f} Mg/ha")

rows = [["Aggregation level", "n", "CCI: bias / RMSE / r²", "GEDI: bias / RMSE / r²"],
        ["(a) Accuracy at three aggregation levels"],
        ["Hexagon", res["CCI"]["hex"][0], cell(res["CCI"]["hex"]), cell(res["GEDI"]["hex"])],
        ["Tribal land", res["CCI"]["tribe"][0], cell(res["CCI"]["tribe"]), cell(res["GEDI"]["tribe"])],
        ["Hexagons with ≥ 8 forested plots", res["CCI"]["well"][0], cell(res["CCI"]["well"]),
         cell(res["GEDI"]["well"])],
        ["(b) Mean bias by region: hexagon level / tribal-land level (n hexagons / n tribal lands)"]]
for g, lab in [("SGP", "SGP"), ("SW", "SW+PNW"), ("NM", "NM+SECP")]:
    c, gd = res["CCI"][g], res["GEDI"][g]
    rows.append([lab, f"{c[0]} / {c[2]}", f"{sg(c[1])} / {sg(c[3])}", f"{sg(gd[1])} / {sg(gd[3])}"])
with open(out("05_sensitivity", "table_S2.csv"), "w", encoding="utf-8-sig", newline="") as f:
    csv.writer(f).writerows(rows)
for r in rows:
    print(" | ".join(str(x) for x in r))
