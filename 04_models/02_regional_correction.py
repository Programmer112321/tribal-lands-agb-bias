"""04/02 - Regional correction models (Sections 2.5.2.1, 3.4; Fig. 5, S5; Table S1)

One XGBoost model per merged region (SGP, SW = SW + PNW, NM = NM + SECP) and product predicts the reference
AGB from the satellite AGB plus the two predictors with the largest mean |SHAP| in that region in the bias model
(script 01). Hyperparameters: 50 random draws scored by CV R^2; CV = 5 shuffled folds (seed 42), or
leave-one-out when a group has fewer than 30 hexagons. If the CV R^2 is negative, the model is refitted with the
satellite AGB plus all ten predictors and that model is kept when its CV R^2 is higher.
Out-of-fold predictions (and SHAP values) come from the same folds with the tuned hyperparameters.

Usage : python 04_models/02_regional_correction.py [table] [bias_name] [name]
        defaults: output/03_predictors/analysis_main_main.csv, "main", "main"
Inputs: analysis table; output/03_predictors/regions.csv; output/04_models/bias_<bias_name>/shap_values_*.csv
Output: output/04_models/regional_<name>/  feature_selection.csv, metrics.csv, best_params.csv,
        predictions.csv (out-of-fold and full-fit predictions per hexagon), shap_importance.csv
"""
import os
import sys

sys.path.insert(0, os.path.join(os.getcwd(), "py"))
from common import (CV_FOLDS, FEATURES, N_ITER, N_JOBS, PRODUCTS, REGIONS, SEED, XGB_GRID, load_table, msg,
                    out, xgb_model)

import joblib
import numpy as np
import pandas as pd
import shap
from sklearn.metrics import mean_squared_error, r2_score
from sklearn.model_selection import KFold, LeaveOneOut, RandomizedSearchCV, cross_validate

table = sys.argv[1] if len(sys.argv) > 1 else out("03_predictors", "analysis_main_main.csv")
bias_name = sys.argv[2] if len(sys.argv) > 2 else "main"
name = sys.argv[3] if len(sys.argv) > 3 else "main"
O = lambda f: out("04_models", f"regional_{name}", f)
SCORING = {"r2": "r2", "rmse": "neg_root_mean_squared_error"}
N_TOP, MIN_N_KFOLD, SAT = 2, 30, "satellite_AGB"

region = pd.read_csv(out("03_predictors", "regions.csv"))[["FID", "Region"]]

# top-2 predictors per region and product from the out-of-fold SHAP values of the bias model
sel, top = [], {}
for prod in PRODUCTS:
    s = pd.read_csv(out("04_models", f"bias_{bias_name}", f"shap_values_{prod}.csv")).merge(region, on="FID")
    for reg in REGIONS:
        r = s[s["Region"] == reg]
        imp = {f: r[f"SHAP_{f}"].abs().mean() for f in FEATURES}
        top[f"{reg}_{prod}"] = sorted(imp, key=imp.get, reverse=True)[:N_TOP]
        sel.append(dict(group=f"{reg}_{prod}", region=reg, product=prod, n_hexagons=len(r),
                        **{f"rank{i + 1}_feature": top[f"{reg}_{prod}"][i] for i in range(N_TOP)},
                        **{f"rank{i + 1}_mean_abs_shap": imp[top[f"{reg}_{prod}"][i]] for i in range(N_TOP)}))
pd.DataFrame(sel).to_csv(O("feature_selection.csv"), index=False)


def fit(X, y, cv):
    with joblib.parallel_config(backend="threading", n_jobs=N_JOBS):
        bp = RandomizedSearchCV(xgb_model(), XGB_GRID, n_iter=N_ITER, cv=cv, scoring=SCORING, refit="r2",
                                n_jobs=N_JOBS, random_state=SEED).fit(X, y).best_params_
        model = xgb_model(**bp).fit(X, y)
        r = cross_validate(model, X, y, cv=cv, scoring=SCORING, n_jobs=N_JOBS)
    return dict(bp=bp, model=model, cv_r2=r["test_r2"].mean(), cv_r2_sd=r["test_r2"].std(),
                cv_rmse=-r["test_rmse"].mean(), cv_rmse_sd=r["test_rmse"].std())


df = load_table(table).merge(region, on="FID", how="left")
assert df["Region"].notna().all()
metrics, params, preds, imps = [], [], [], []
for reg in REGIONS:
    for prod in PRODUCTS:
        grp = f"{reg}_{prod}"
        g = df[(df["Region"] == reg) & (df["AGB product"] == prod)]
        feats = [SAT] + top[grp]
        d = g.dropna(subset=["AGB REF"] + feats)
        cv = LeaveOneOut() if len(d) < MIN_N_KFOLD else KFold(n_splits=CV_FOLDS, shuffle=True, random_state=SEED)
        res, fallback = fit(d[feats], d["AGB REF"], cv), False
        if res["cv_r2"] < 0:                                   # fallback: satellite + all ten predictors
            fa = [SAT] + FEATURES
            da = d.dropna(subset=fa)
            alt = fit(da[fa], da["AGB REF"], cv)
            if alt["cv_r2"] > res["cv_r2"]:
                res, feats, d, fallback = alt, fa, da, True
        X, y = d[feats], d["AGB REF"]

        sv, pred = np.zeros(X.shape), np.zeros(len(X))
        for tr, te in cv.split(X.values):
            m = xgb_model(**res["bp"]).fit(X.values[tr], y.values[tr])
            pred[te] = m.predict(X.values[te])
            sv[te] = shap.TreeExplainer(m, feature_perturbation="tree_path_dependent").shap_values(X.values[te])
        full = res["model"].predict(X)

        metrics.append(dict(group=grp, region=reg, product=prod, n=len(X),
                            cv="leave-one-out" if isinstance(cv, LeaveOneOut) else f"{CV_FOLDS}-fold",
                            features=" + ".join(feats), fallback_all_predictors=fallback,
                            cv_r2=res["cv_r2"], cv_r2_sd=res["cv_r2_sd"], cv_rmse=res["cv_rmse"],
                            cv_rmse_sd=res["cv_rmse_sd"], train_r2=r2_score(y, full),
                            train_rmse=np.sqrt(mean_squared_error(y, full)), oof_r2=r2_score(y, pred),
                            oof_rmse=np.sqrt(mean_squared_error(y, pred))))
        params.append(dict(group=grp, **res["bp"]))
        preds.append(pd.DataFrame({"FID": d["FID"].values, "Tribe": d["Tribe"].values, "Region": reg,
                                   "AGB product": prod, SAT: d[SAT].values, "AGB_REF_actual": y.values,
                                   "AGB_REF_predicted": pred, "AGB_REF_pred_full": full}))
        imps.append(pd.DataFrame({"group": grp, "feature": feats, "mean_abs_shap": np.abs(sv).mean(axis=0)})
                    .sort_values("mean_abs_shap", ascending=False))
        msg(f"{grp}: n={len(X)} {' + '.join(feats)}{' (fallback)' if fallback else ''} | "
            f"CV R2={res['cv_r2']:.4f} RMSE={res['cv_rmse']:.3f} | OOF R2={metrics[-1]['oof_r2']:.4f}")

pd.DataFrame(metrics).to_csv(O("metrics.csv"), index=False)
pd.DataFrame(params).to_csv(O("best_params.csv"), index=False)
pd.concat(preds).to_csv(O("predictions.csv"), index=False)
pd.concat(imps).to_csv(O("shap_importance.csv"), index=False)
msg("done ->", os.path.dirname(O("metrics.csv")))
