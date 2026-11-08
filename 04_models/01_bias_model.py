"""04/01 - Bias model: what explains the satellite-minus-reference bias? (Sections 2.5.1, 3.2; Fig. 3, 4)

For each product separately:
  * XGBoost regression of the bias (AGB = satellite - reference) on the ten predictors;
  * hyperparameters: 50 random draws from the search space, scored by 5-fold CV R^2 (shuffled folds, seed 42);
  * reported CV R^2 / RMSE = mean over the same five folds of the tuned model;
  * SHAP: out-of-fold (each hexagon is explained by the fold model that did not see it; same folds and
    tuned hyperparameters); importance = mean |SHAP| per predictor;
  * response curves (Fig. 3, S3): prediction of the model fitted to all hexagons when one predictor runs from
    its 1st to its 99th percentile (100 steps) and the others are held at their medians.

Usage : python 04_models/01_bias_model.py [table] [name]
        table default output/03_predictors/analysis_main_main.csv, name default "main"
Output: output/04_models/bias_<name>/  metrics.csv, best_params.csv, shap_values_<P>.csv,
        shap_importance_<P>.csv, response_curves_<P>.csv   (P = CCI, GEDI)
"""
import os
import sys

sys.path.insert(0, os.path.join(os.getcwd(), "py"))
from common import (CV_FOLDS, FEATURES, N_ITER, N_JOBS, PRODUCTS, SEED, XGB_GRID, load_table, msg, out,
                    xgb_model)

import joblib
import numpy as np
import pandas as pd
import shap
from sklearn.metrics import mean_squared_error, r2_score
from sklearn.model_selection import KFold, RandomizedSearchCV, cross_validate

table = sys.argv[1] if len(sys.argv) > 1 else out("03_predictors", "analysis_main_main.csv")
name = sys.argv[2] if len(sys.argv) > 2 else "main"
O = lambda f: out("04_models", f"bias_{name}", f)
SCORING = {"r2": "r2", "rmse": "neg_root_mean_squared_error"}

df = load_table(table)
msg(f"bias model '{name}': {table} ({len(df)} rows)")
metrics, params = [], []

for prod in PRODUCTS:
    g = df[df["AGB product"] == prod]
    g = g.dropna(subset=FEATURES + ["AGB"])
    X, y, fid = g[FEATURES], g["AGB"], g["FID"].values
    cv = KFold(n_splits=CV_FOLDS, shuffle=True, random_state=SEED)

    with joblib.parallel_config(backend="threading", n_jobs=N_JOBS):
        search = RandomizedSearchCV(xgb_model(), XGB_GRID, n_iter=N_ITER, cv=cv, scoring=SCORING, refit="r2",
                                    n_jobs=N_JOBS, random_state=SEED).fit(X, y)
        bp = search.best_params_
        model = xgb_model(**bp).fit(X, y)
        cvr = cross_validate(model, X, y, cv=cv, scoring=SCORING, n_jobs=N_JOBS)

    # out-of-fold predictions and SHAP values
    sv, base, pred = np.zeros(X.shape), np.zeros(len(X)), np.zeros(len(X))
    fold = np.full(len(X), -1)
    for k, (tr, te) in enumerate(cv.split(X.values)):
        m = xgb_model(**bp).fit(X.values[tr], y.values[tr])
        pred[te] = m.predict(X.values[te])
        ex = shap.TreeExplainer(m, feature_perturbation="tree_path_dependent")
        sv[te] = ex.shap_values(X.values[te])
        base[te] = float(ex.expected_value)
        fold[te] = k

    fit = model.predict(X)
    metrics.append(dict(product=prod, n=len(X), cv_r2=cvr["test_r2"].mean(), cv_r2_sd=cvr["test_r2"].std(),
                        cv_rmse=-cvr["test_rmse"].mean(), cv_rmse_sd=cvr["test_rmse"].std(),
                        train_r2=r2_score(y, fit), train_rmse=np.sqrt(mean_squared_error(y, fit)),
                        oof_r2=r2_score(y, pred), oof_rmse=np.sqrt(mean_squared_error(y, pred))))
    params.append(dict(product=prod, **bp))

    s = pd.DataFrame({"FID": fid, "Tribe": g["Tribe"].values, "AGB product": prod})
    for j, f in enumerate(FEATURES):
        s[f"SHAP_{f}"] = sv[:, j]
    s = s.assign(AGB_actual=y.values, AGB_predicted=pred, AGB_predicted_full=fit, SHAP_base_value=base,
                 SHAP_sum=sv.sum(axis=1), fold_id=fold)
    s.to_csv(O(f"shap_values_{prod}.csv"), index=False)
    imp = (pd.DataFrame({"feature": FEATURES, "mean_abs_shap": np.abs(sv).mean(axis=0)})
           .sort_values("mean_abs_shap", ascending=False))
    imp.to_csv(O(f"shap_importance_{prod}.csv"), index=False)

    # response curves of the model fitted to all hexagons
    rc = []
    for f in FEATURES:
        xr = np.linspace(X[f].quantile(0.01), X[f].quantile(0.99), 100)
        bg = pd.DataFrame(np.tile(X.median().values, (100, 1)), columns=FEATURES)
        bg[f] = xr
        rc.append(pd.DataFrame({"feature": f, "value": xr, "predicted_bias": model.predict(bg)}))
    pd.concat(rc).to_csv(O(f"response_curves_{prod}.csv"), index=False)

    msg(f"{prod}: n={len(X)} CV R2={metrics[-1]['cv_r2']:.4f} RMSE={metrics[-1]['cv_rmse']:.3f} | top SHAP: "
        + ", ".join(f"{a} {b:.2f}" for a, b in imp.head(5).values))

pd.DataFrame(metrics).to_csv(O("metrics.csv"), index=False)
pd.DataFrame(params).to_csv(O("best_params.csv"), index=False)
msg("done ->", os.path.dirname(O("metrics.csv")))
