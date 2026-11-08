"""Appendix Table S1 - TreeMap 2020 layers (imputed from FIA plots) vs layers not imputed from FIA
(canopy height GLAD 2019, forest age GAMI 2020, tree density Crowther et al. 2015)

 (a) bias model: CV R^2 (CV RMSE)       (b) five most important predictors (mean |SHAP|)
 (c) regional correction models: CV R^2 (CV RMSE) [predictors used]; mean CV R^2 of the six models

Usage : python 06_figures_tables/table_S1.py
Inputs: output/04_models/{bias,regional}_{main,nonfia}/
Output: output/06_figures_tables/table_S1.csv
"""
import csv
import os
import sys

sys.path.insert(0, os.path.join(os.getcwd(), "py"))
from common import PRODUCTS, REGIONS, out

import pandas as pd

RUNS = {"main": "TreeMap 2020 layers (imputed from FIA)",
        "nonfia": "Layers not imputed from FIA (GLAD, GAMI, Crowther)"}
NAMES = {"main": {}, "nonfia": {"Stand density": "tree density"}}
f2 = lambda v: f"{v:.2f}".replace("-", "−")
f1 = lambda v: f"{v:.1f}"
name = lambda run, f: NAMES[run].get(f, f if f == "AWC" else f.lower())


def bias(run, prod):
    m = pd.read_csv(out("04_models", f"bias_{run}", "metrics.csv")).set_index("product").loc[prod]
    return f"{f2(m.cv_r2)} ({f1(m.cv_rmse)})"


def top5(run, prod):
    s = pd.read_csv(out("04_models", f"bias_{run}", f"shap_importance_{prod}.csv")).head(5)
    j = ", ".join(f"{name(run, f)} ({f1(v)})" for f, v in s.values)
    return j[0].upper() + j[1:]


reg = {r: pd.read_csv(out("04_models", f"regional_{r}", "metrics.csv")).set_index("group") for r in RUNS}


def regcell(run, grp):
    m = reg[run].loc[grp]
    used = "[all 10 factors]ᵃ" if m.fallback_all_predictors else \
        "[" + ", ".join(name(run, f) for f in m.features.split(" + ")[1:]) + "]"
    return f"{f2(m.cv_r2)} ({f1(m.cv_rmse)}) {used}"


rows = [["", *RUNS.values()],
        ["(a) Bias model: CV R² (CV RMSE, Mg ha⁻¹), n = 257"],
        *[[p, *(bias(r, p) for r in RUNS)] for p in PRODUCTS],
        ["(b) Bias model: five most important factors (mean |SHAP|, Mg ha⁻¹)"],
        *[[p, *(top5(r, p) for r in RUNS)] for p in PRODUCTS],
        ["(c) Regional correction model: CV R² (CV RMSE, Mg ha⁻¹) [two factors used]"]]
for g, lab in zip(REGIONS, ["SGP", "SW+PNW", "NM+SECP"]):
    for i, p in enumerate(PRODUCTS):
        n = reg["main"].loc[f"{g}_{p}", "n"]
        rows.append([f"{lab}, {p}" + (f" (n = {n})" if i == 0 else ""), *(regcell(r, f"{g}_{p}") for r in RUNS)])
rows.append(["Mean of the six models", *(f2(reg[r].cv_r2.mean()) for r in RUNS)])

with open(out("06_figures_tables", "table_S1.csv"), "w", encoding="utf-8-sig", newline="") as f:
    csv.writer(f).writerows(rows)
for r in rows:
    print(" | ".join(r))
