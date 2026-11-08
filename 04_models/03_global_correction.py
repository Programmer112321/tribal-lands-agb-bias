"""04/03 - Global correction models (Sections 2.5.2.1, 3.4; Fig. 5, S5)

One XGBoost model per product over all hexagons predicts the reference AGB from the satellite AGB and all ten
predictors. Hyperparameters: 50 random draws scored by 5-fold CV R^2 (shuffled, seed 42); out-of-fold predictions from the
same folds with the tuned hyperparameters; full-fit predictions for the overfitting gap.

Usage : python 04_models/03_global_correction.py [table] [name]
        defaults: output/03_predictors/analysis_main_main.csv, "main"
Inputs: analysis table; output/03_predictors/regions.csv
Output: output/04_models/global_<name>/  predictions.csv (out-of-fold and full-fit), best_params.csv, metrics.csv
"""
import os
import sys

sys.path.insert(0, os.path.join(os.getcwd(), "py"))
from common import CV_FOLDS, FEATURES, N_ITER, N_JOBS, PRODUCTS, SEED, XGB_GRID, load_table, msg, out, xgb_model

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import mean_squared_error, r2_score
from sklearn.model_selection import KFold, RandomizedSearchCV

table = sys.argv[1] if len(sys.argv) > 1 else out("03_predictors", "analysis_main_main.csv")
name = sys.argv[2] if len(sys.argv) > 2 else "main"
O = lambda f: out("04_models", f"global_{name}", f)
SAT = "satellite_AGB"
feats = [SAT] + FEATURES

df = load_table(table).merge(pd.read_csv(out("03_predictors", "regions.csv"))[["FID", "Region", "Region_orig"]],
                             on="FID", how="left")
params, metrics, frames = [], [], []
for prod in PRODUCTS:
    sub = df[df["AGB product"] == prod].dropna(subset=["AGB REF"] + feats).reset_index(drop=True)
    X, y = sub[feats].values, sub["AGB REF"].values
    cv = KFold(n_splits=CV_FOLDS, shuffle=True, random_state=SEED)
    with joblib.parallel_config(backend="threading", n_jobs=N_JOBS):   # threads, as in 01 and 02
        bp = RandomizedSearchCV(xgb_model(), XGB_GRID, n_iter=N_ITER, cv=cv, scoring="r2", refit=True,
                                n_jobs=N_JOBS, random_state=SEED).fit(X, y).best_params_
    oof = np.full(len(sub), np.nan)
    for tr, te in cv.split(X):
        oof[te] = xgb_model(**bp).fit(X[tr], y[tr]).predict(X[te])
    full = xgb_model(**bp).fit(X, y).predict(X)
    frames.append(sub[["FID", "Tribe", "Region", "Region_orig", "AGB product", SAT]]
                  .assign(AGB_REF_actual=y, AGB_REF_predicted=oof, AGB_REF_pred_full=full))
    params.append(dict(product=prod, **bp))
    metrics.append(dict(product=prod, n=len(sub),
                        oof_r2=r2_score(y, oof), oof_rmse=np.sqrt(mean_squared_error(y, oof)),
                        train_r2=r2_score(y, full), train_rmse=np.sqrt(mean_squared_error(y, full))))
    msg(f"{prod}: n={len(sub)} OOF R2={metrics[-1]['oof_r2']:.4f} RMSE={metrics[-1]['oof_rmse']:.3f}")
pd.concat(frames, ignore_index=True).to_csv(O("predictions.csv"), index=False)

pd.DataFrame(params).to_csv(O("best_params.csv"), index=False)
pd.DataFrame(metrics).to_csv(O("metrics.csv"), index=False)
msg("done ->", os.path.dirname(O("metrics.csv")))
