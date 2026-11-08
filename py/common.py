"""Shared setup for the Python scripts (stages 04-06). Run every script from the repository root."""
import os
import sys
import time

import yaml

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.abspath(os.getcwd())
if not os.path.exists(os.path.join(ROOT, "config.yml")):
    sys.exit("Run the scripts from the repository root (config.yml not found).")
with open(os.path.join(ROOT, "config.yml"), encoding="utf-8") as f:
    CFG = yaml.safe_load(f)
SET = CFG["settings"]
SEED = SET["seed"]
N_JOBS = SET["workers"]

# the ten predictors, in the order used by every model (the order matters for XGBoost column sampling)
FEATURES = ["Canopy height", "Forest age", "Soil moisture", "AWC", "Stand density", "Wood density",
            "Structural diversity", "Elevation", "Slope", "Northness"]
PRODUCTS = ["CCI", "GEDI"]
REGIONS = ["SGP", "SW", "NM"]                     # merged regions: SW = SW + PNW, NM = NM + SECP
CV_FOLDS = 5
N_ITER = 50                                       # random hyperparameter draws

# XGBoost search space (bias model and regional correction models)
XGB_GRID = {
    "n_estimators": [200, 400, 600],
    "max_depth": [4, 6, 8, 10],
    "learning_rate": [0.01, 0.05, 0.1, 0.2],
    "subsample": [0.7, 0.8, 0.9],
    "colsample_bytree": [0.7, 0.8, 0.9],
    "min_child_weight": [1, 3, 5],
    "gamma": [0, 0.1, 0.3],
}
# fixed settings of the global correction model (no search)
XGB_GLOBAL = dict(n_estimators=400, max_depth=6, learning_rate=0.05, subsample=0.8, colsample_bytree=0.8,
                  min_child_weight=3, gamma=0.1)


def out(*parts):
    """Path under the output folder; creates the parent folder."""
    base = CFG["output_dir"] if os.path.isabs(CFG["output_dir"]) else os.path.join(ROOT, CFG["output_dir"])
    p = os.path.join(base, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def xgb_model(**params):
    import xgboost as xgb
    return xgb.XGBRegressor(**params, random_state=SEED, n_jobs=1, tree_method="hist",
                            objective="reg:squarederror")


def load_table(path):
    """Analysis table from stage 03 with the satellite AGB added (AGB = bias = satellite - reference)."""
    import pandas as pd
    d = pd.read_csv(path)
    d["satellite_AGB"] = d["AGB"] + d["AGB REF"]
    return d


def msg(*a):
    print(time.strftime("%H:%M:%S"), "|", *a, flush=True)
