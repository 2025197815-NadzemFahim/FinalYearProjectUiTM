import argparse
import json
import time

import joblib
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.multioutput import MultiOutputClassifier

from ml import config
from ml.data import load_brfss, load_layer2
from ml.evaluate import bootstrap_ci, compare_models, print_ci, print_summary
from ml.stacking import StackedEnsemble


def _subsample(X, y, n, seed):
    if n is None or n >= len(X):
        return X, y
    Xs, _, ys, _ = train_test_split(X, y, train_size=n, stratify=y, random_state=seed)
    return Xs, ys


# ---------------------------------------------------------------- shared splits
# Training (ml.train) and the confidence-interval script (ml.ci) both call
# these, so they always see exactly the same 80:20 test set.
def layer1_split(sample=None):
    """80:20 split of BRFSS, stratified on the combination of all three labels."""
    X, Y = load_brfss()
    targets = config.BRFSS_TARGETS
    # Stratify on the combination of all three labels (e.g. "2-1-0") so the
    # split keeps every disease mix in proportion. Tiny dev samples may have
    # combinations with < 2 rows; fall back to the diabetes label then.
    key = Y.astype(str).agg("-".join, axis=1)
    if sample:
        X, _, Y, _, key, _ = train_test_split(X, Y, key, train_size=sample, stratify=Y[targets[0]],
                                              random_state=config.RANDOM_STATE)
    strat = key if key.value_counts().min() >= 2 else Y[targets[0]]
    return train_test_split(X, Y, test_size=config.TEST_SIZE, stratify=strat,
                            random_state=config.RANDOM_STATE)


def layer2_split(name, sample=None):
    """80:20 split of one deep-check dataset, stratified on its target."""
    X, y = load_layer2(name)
    X, y = _subsample(X, y.to_numpy(), sample, config.RANDOM_STATE)
    return train_test_split(X, y, test_size=config.TEST_SIZE, stratify=y,
                            random_state=config.RANDOM_STATE)


def evaluate_with_ci(title, model, X_te, y_te, n_boot=None):
    """Point scores + bootstrap confidence intervals, printed and returned."""
    results = compare_models(model, X_te, y_te)
    print_summary(f"{title} - held-out test set", results)
    t = time.time()
    ci = bootstrap_ci(model, X_te, y_te, n_boot=n_boot)
    print_ci(title, results, ci)
    print(f"    (confidence intervals took {time.time() - t:.0f}s)")
    return results, ci


def _save(name, model, report, sample, t0):
    config.MODELS.mkdir(parents=True, exist_ok=True)
    config.REPORTS.mkdir(parents=True, exist_ok=True)
    suffix = f"_dev{sample}" if sample else ""
    joblib.dump(model, config.MODELS / f"{name}{suffix}.joblib", compress=3)
    report["train_seconds"] = round(time.time() - t0)
    (config.REPORTS / f"{name}{suffix}.json").write_text(json.dumps(report, indent=2))
    print(f"\n  saved ml/models/{name}{suffix}.joblib ({time.time() - t0:.0f}s total)")


def train_layer1(sample=None):
    """Model 1: ONE multi-output model that predicts all three diseases.

    MultiOutputClassifier holds one StackedEnsemble per target over the same
    19 BRFSS features, but it is a single estimator: one fit(), one
    predict_proba(), one saved file. A single shared ensemble isn't possible
    because LightGBM can't predict several targets at once and SMOTE-Tomek
    can only rebalance one target at a time.
    """
    t0 = time.time()
    targets = config.BRFSS_TARGETS
    X_tr, X_te, Y_tr, Y_te = layer1_split(sample)
    print(f"\n=== layer1_general (Model 1): train {len(X_tr):,} / test {len(X_te):,} | "
          f"targets {targets} | SMOTE-Tomek on")

    # Fitted sequentially, one target after another, in the order of `targets`
    model = MultiOutputClassifier(StackedEnsemble(
        numeric=config.BRFSS_FEATURES, categorical=[], use_resampling=True))
    model.fit(X_tr, Y_tr.to_numpy())

    results, cis = {}, {}
    for target, est in zip(targets, model.estimators_):
        results[target], cis[target] = evaluate_with_ci(
            f"layer1_general -> {target}", est, X_te, Y_te[target].to_numpy())

    report = {"model": "layer1_general", "rows_train": len(X_tr), "rows_test": len(X_te),
              "features": config.BRFSS_FEATURES, "targets": targets, "smote_tomek": True,
              "minority_ratio": config.MINORITY_RATIO,
              "classes": {t: e.classes_.tolist() for t, e in zip(targets, model.estimators_)},
              "results": results, "confidence_intervals": cis}
    _save("layer1_general", model, report, sample, t0)


def train_one(name, spec, sample=None):
    t0 = time.time()
    X_tr, X_te, y_tr, y_te = layer2_split(name, sample)
    dist = (pd.Series(y_tr).value_counts(normalize=True).sort_index() * 100).round(2)
    print(f"\n=== layer2_{name}: train {len(X_tr):,} / test {len(X_te):,} | "
          f"class % {dist.to_dict()} | SMOTE-Tomek {'on' if spec['resample'] else 'off'}")

    model = StackedEnsemble(numeric=spec["numeric"], categorical=spec["categorical"],
                            use_resampling=spec["resample"]).fit(X_tr, y_tr)
    results, ci = evaluate_with_ci(f"layer2_{name}", model, X_te, y_te)

    report = {
        "model": f"layer2_{name}", "rows_train": len(X_tr), "rows_test": len(X_te),
        "features": spec["numeric"] + spec["categorical"], "smote_tomek": spec["resample"],
        "minority_ratio": config.MINORITY_RATIO, "classes": model.classes_.tolist(),
        "results": results, "confidence_intervals": ci,
    }
    _save(f"layer2_{name}", model, report, sample, t0)
    return report


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--layer1", action="store_true",
                    help="train Model 1: one multi-output BRFSS model (3 diseases)")
    ap.add_argument("--layer2", nargs="+", choices=list(config.LAYER2) + ["all"],
                    help="deep-check models to train")
    ap.add_argument("--sample", type=int, default=None,
                    help="stratified subsample size for quick dev runs")
    args = ap.parse_args()
    if not args.layer1 and not args.layer2:
        ap.error("choose --layer1 and/or --layer2")

    if args.layer1:
        train_layer1(sample=args.sample)

    if args.layer2:
        names = list(config.LAYER2) if "all" in args.layer2 else args.layer2
        for name in names:
            train_one(name, config.LAYER2[name], sample=args.sample)


if __name__ == "__main__":
    np.random.seed(config.RANDOM_STATE)
    main()
