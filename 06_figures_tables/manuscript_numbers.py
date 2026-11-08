"""Numbers quoted in the Abstract, Results and Discussion

 1. raw accuracy (Fig. 2a): mean reference / satellite / bias, share of hexagons overestimated, RMSE,
    R^2 = squared Pearson r, least-squares line; all hexagons, original regions, merged regions
 2. accuracy per tribal land (Fig. S1): R^2 = 1 - SSE/SST and RMSE
 3. bias model (Fig. 3): CV R^2, rank and mean |SHAP| of each predictor, direction = Spearman rho of predictor value
    vs its SHAP value
 4. dominant factor per hexagon (Fig. 4, S4): share of hexagons by region
 5. total AGB over the hexagons (Tg): density x hexagon area inside tribal lands; overestimation removed by the
    regional and global correction models (out-of-fold predictions)
 6. FIA plots behind the reference (2018-2022), per region

Usage : python 06_figures_tables/manuscript_numbers.py
Output: output/06_figures_tables/manuscript_numbers.txt
"""
import os
import sys

sys.path.insert(0, os.path.join(os.getcwd(), "py"))
from common import FEATURES, PRODUCTS, load_table, out

import numpy as np
import pandas as pd
from scipy.stats import spearmanr

lines = []


def p(*a):
    s = " ".join(str(x) for x in a)
    print(s)
    lines.append(s)


reg = pd.read_csv(out("03_predictors", "regions.csv"))
df = load_table(out("03_predictors", "analysis_main_main.csv")).merge(
    reg[["FID", "Region", "Region_orig", "tribal_area_ha"]], on="FID", how="left")
df["sat"] = df["satellite_AGB"]
p("hexagons per product:", df.groupby("AGB product").FID.nunique().to_dict())

p("\n== 1. Raw accuracy: satellite vs reference ==")


def acc(d):
    e = d.sat - d["AGB REF"]
    fit = np.polyfit(d["AGB REF"], d.sat, 1)
    return pd.Series({"n": len(d), "mean_ref": d["AGB REF"].mean(), "mean_sat": d.sat.mean(), "mean_bias": e.mean(),
                      "median_bias": e.median(), "min_bias": e.min(), "max_bias": e.max(),
                      "share_over_%": 100 * (e > 0).mean(), "RMSE": np.sqrt((e ** 2).mean()),
                      "R2_pearson": d.sat.corr(d["AGB REF"]) ** 2, "slope": fit[0], "intercept": fit[1]})


for key in [None, "Region_orig", "Region"]:
    g = df.groupby("AGB product") if key is None else df.groupby([key, "AGB product"])
    p(g.apply(acc, include_groups=False).round(2).to_string())

p("\n== 2. Per tribal land: R^2 (1 - SSE/SST) and RMSE ==")


def tribe_m(d):
    e = d.sat - d["AGB REF"]
    sst = ((d["AGB REF"] - d["AGB REF"].mean()) ** 2).sum()
    return pd.Series({"n": len(d), "R2": 1 - (e ** 2).sum() / sst if sst > 0 else np.nan, "RMSE": np.sqrt((e ** 2).mean())})


tm = df.groupby(["AGB product", "Tribe"]).apply(tribe_m, include_groups=False).reset_index()
for prod, d in tm.groupby("AGB product"):
    p(prod, f"tribal lands={len(d)}",
      "R2 median=%.2f IQR=[%.2f, %.2f] share>0=%.0f%% share>0.5=%.0f%%" % (
          d.R2.median(), d.R2.quantile(.25), d.R2.quantile(.75), 100 * (d.R2 > 0).mean(), 100 * (d.R2 > 0.5).mean()),
      "| RMSE median=%.1f IQR=[%.1f, %.1f] min=%.1f max=%.1f sd=%.1f" % (
          d.RMSE.median(), d.RMSE.quantile(.25), d.RMSE.quantile(.75), d.RMSE.min(), d.RMSE.max(), d.RMSE.std()))

p("\n== 3. Bias model: CV R^2; SHAP rank, mean |SHAP|, direction (Spearman rho of value vs SHAP) ==")
bm = pd.read_csv(out("04_models", "bias_main", "metrics.csv")).set_index("product")
shap = pd.concat([pd.read_csv(out("04_models", "bias_main", f"shap_values_{q}.csv")) for q in PRODUCTS],
                 ignore_index=True)
for prod, d in shap.groupby("AGB product"):
    v = df[df["AGB product"] == prod].set_index("FID").loc[d.FID]
    rows = sorted(((f, np.abs(d[f"SHAP_{f}"]).mean(), spearmanr(v[f], d[f"SHAP_{f}"]).correlation) for f in FEATURES),
                  key=lambda r: -r[1])
    p(f"{prod}: CV R2 {bm.loc[prod, 'cv_r2']:.4f} (out-of-fold {bm.loc[prod, 'oof_r2']:.4f}), CV RMSE "
      f"{bm.loc[prod, 'cv_rmse']:.2f} | " + "; ".join(f"{i + 1}. {f} {m:.2f} (rho {r:+.2f})"
                                                      for i, (f, m, r) in enumerate(rows)))

p("\n== 4. Dominant factor per hexagon (max |SHAP|), % of hexagons ==")
sc = [f"SHAP_{f}" for f in FEATURES]
top = shap.assign(top=shap[sc].abs().idxmax(axis=1).str.replace("SHAP_", "")).merge(reg, on="FID")
for key in ["Region_orig", None]:
    for prod, d0 in top.groupby("AGB product"):
        for r, d in ([("All", d0)] if key is None else list(d0.groupby(key))):
            sh = (100 * d.top.value_counts(normalize=True)).round(1)
            p(f"{prod} {r} (n={len(d)}): " + ", ".join(f"{k} {v}%" for k, v in sh.items()))

p("\n== 5. Total AGB over the hexagons (density x hexagon area inside tribal lands), Tg ==")
area = reg[["FID", "tribal_area_ha"]]
rg = pd.read_csv(out("04_models", "regional_main", "predictions.csv")).merge(area, on="FID")
gl = pd.read_csv(out("04_models", "global_main", "predictions.csv")).merge(area, on="FID")
for prod in PRODUCTS:
    r = df[df["AGB product"] == prod]
    raw_b = (r.AGB * r.tribal_area_ha).sum() / 1e6
    ref_t = (r["AGB REF"] * r.tribal_area_ha).sum() / 1e6
    p(f"{prod}: area {r.tribal_area_ha.sum():.0f} ha | reference {ref_t:.1f} Tg | satellite {ref_t + raw_b:.1f} Tg | "
      f"overestimation {raw_b:.1f} Tg")
    for lab, x in [("regional", rg[rg["AGB product"] == prod]), ("global", gl[gl["AGB product"] == prod])]:
        b = ((x.AGB_REF_predicted - x.AGB_REF_actual) * x.tribal_area_ha).sum() / 1e6
        p(f"   {lab}: n={x.FID.nunique()} bias {b:+.1f} Tg | overestimation removed {abs(raw_b) - abs(b):.1f} Tg "
          f"({100 * (abs(raw_b) - abs(b)) / abs(raw_b):.1f}%) | RMSE "
          f"{np.sqrt(((x.AGB_REF_predicted - x.AGB_REF_actual) ** 2).mean()):.2f}")

p("\n== 6. Forested FIA plots (2018-2022) behind the reference of the analysed hexagons ==")
pl = pd.read_csv(out("02_reference", "reference_plots_2018_2022.csv"))
pl = pl[pl.FID.isin(df.FID)].merge(reg[["FID", "Region_orig", "Region"]], on="FID")
p(f"plots: {pl.PLT_CN.nunique()} | per original region: {pl.groupby('Region_orig').PLT_CN.nunique().to_dict()} | "
  f"per merged region: {pl.groupby('Region').PLT_CN.nunique().to_dict()}")
p(f"plots per hexagon: median {pl.groupby('FID').size().median():.0f}, "
  f"range {pl.groupby('FID').size().min()}-{pl.groupby('FID').size().max()}")

with open(out("06_figures_tables", "manuscript_numbers.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
