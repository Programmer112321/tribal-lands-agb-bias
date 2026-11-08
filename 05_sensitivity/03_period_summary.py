"""05/03 - Inventory-period sensitivity (Sections 2.3, 3.2)

Compares the bias analysis of the main run (FIA plots 2018-2022, CCI 2020) with
  period   FIA plots 2019-2023 and CCI 2021 (both changed),
  splitA   FIA plots 2019-2023, CCI 2020 (only the FIA years changed),
  splitB   FIA plots 2018-2022, CCI 2021 (only the CCI year changed).
GEDI L4B is the same in every run. Run the steps listed in the README first (stage 02 for 2019-2023 / CCI 2021,
the analysis tables and the bias model for each run).

Usage : python 05_sensitivity/03_period_summary.py
Output: output/05_sensitivity/period_summary.csv (one row per run and product: hexagons, mean bias, RMSE,
        bias-model CV R^2, the six most important predictors with mean |SHAP|)
"""
import os
import sys

sys.path.insert(0, os.path.join(os.getcwd(), "py"))
from common import PRODUCTS, load_table, out

import numpy as np
import pandas as pd

RUNS = {"main": "FIA 2018-2022, CCI 2020", "period": "FIA 2019-2023, CCI 2021",
        "splitA": "FIA 2019-2023, CCI 2020", "splitB": "FIA 2018-2022, CCI 2021"}
rows = []
for run, label in RUNS.items():
    d = load_table(out("03_predictors", f"analysis_{run}_main.csv"))
    m = pd.read_csv(out("04_models", f"bias_{run}", "metrics.csv")).set_index("product")
    for p in PRODUCTS:
        q = d[d["AGB product"] == p]
        imp = pd.read_csv(out("04_models", f"bias_{run}", f"shap_importance_{p}.csv"))
        rows.append(dict(run=run, inputs=label, product=p, hexagons=len(q), mean_bias=q["AGB"].mean(),
                         RMSE=np.sqrt((q["AGB"] ** 2).mean()), bias_model_cv_r2=m.loc[p, "cv_r2"],
                         top6=" > ".join(f"{a} ({b:.1f})" for a, b in imp.head(6).values)))
s = pd.DataFrame(rows)
s.to_csv(out("05_sensitivity", "period_summary.csv"), index=False)
pd.set_option("display.width", 250, "display.max_colwidth", 140)
print(s.round(2).to_string(index=False))
