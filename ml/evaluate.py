import numpy as np
from sklearn.metrics import (accuracy_score, average_precision_score,
                             balanced_accuracy_score, confusion_matrix,
                             f1_score, precision_score, recall_score,
                             roc_auc_score)

from ml import config


def decide(proba: np.ndarray, threshold=None, class_weights=None) -> np.ndarray:
    """Turn probabilities into class predictions.

    Binary: tuned threshold. Multi-class: tuned per-class weights.
    Models without either (older saves) fall back to argmax.
    """
    binary = proba.shape[1] == 2
    if binary and threshold is not None:
        return (proba[:, 1] >= threshold).astype(int)
    if not binary and class_weights is not None:
        return (proba * np.asarray(class_weights)).argmax(axis=1)
    return proba.argmax(axis=1)


def classification_metrics(y_true, proba: np.ndarray, threshold=None, class_weights=None) -> dict:
    y_true = np.asarray(y_true)
    binary = proba.shape[1] == 2
    y_pred = decide(proba, threshold, class_weights)
    avg = "binary" if binary else "macro"
    m = {
        "threshold": threshold,
        # plain list: json.dumps can't save NumPy arrays
        "class_weights": None if class_weights is None
                         else [round(float(v), 3) for v in class_weights],
        "accuracy": accuracy_score(y_true, y_pred),
        "balanced_accuracy": balanced_accuracy_score(y_true, y_pred),
        "precision": precision_score(y_true, y_pred, average=avg, zero_division=0),
        "recall": recall_score(y_true, y_pred, average=avg, zero_division=0),
        "f1": f1_score(y_true, y_pred, average=avg, zero_division=0),
        "recall_per_class": recall_score(y_true, y_pred, average=None, zero_division=0).tolist(),
        "confusion_matrix": confusion_matrix(y_true, y_pred).tolist(),
    }
    if binary:
        m["roc_auc"] = roc_auc_score(y_true, proba[:, 1])
        m["pr_auc"] = average_precision_score(y_true, proba[:, 1])
    else:
        m["roc_auc"] = roc_auc_score(y_true, proba, multi_class="ovr", average="macro")
    return {k: (round(float(v), 4) if isinstance(v, (float, np.floating)) else v)
            for k, v in m.items()}


def compare_models(model, X_test, y_test) -> dict:
    # Every model is judged at its own threshold / class weights, all chosen
    # the same way from training out-of-fold predictions -> a fair comparison
    th = getattr(model, "thresholds_", {})
    cw = getattr(model, "class_weights_", {})
    results = {"stacked_ensemble": classification_metrics(
        y_test, model.predict_proba(X_test), th.get("stacked_ensemble"), cw.get("stacked_ensemble"))}
    for name, proba in model.base_predict_proba(X_test).items():
        results[name] = classification_metrics(y_test, proba, th.get(name), cw.get(name))
    return results


# ---------------------------------------------------------------- confidence intervals
CI_METRICS = ["f1", "recall", "roc_auc", "pr_auc"]


def _core_metrics(y, proba, y_pred, binary) -> dict:
    avg = "binary" if binary else "macro"
    m = {"f1": f1_score(y, y_pred, average=avg, zero_division=0),
         "recall": recall_score(y, y_pred, average=avg, zero_division=0)}
    if binary:
        m["roc_auc"] = roc_auc_score(y, proba[:, 1])
        m["pr_auc"] = average_precision_score(y, proba[:, 1])
    else:
        m["roc_auc"] = roc_auc_score(y, proba, multi_class="ovr", average="macro")
    return m


def _ci(values) -> list:
    """95% percentile interval."""
    return [round(float(np.percentile(values, 2.5)), 4), round(float(np.percentile(values, 97.5)), 4)]


def bootstrap_ci(model, X_test, y_test, n_boot=None, seed=None) -> dict:
    """95% confidence intervals by bootstrapping the held-out test set.

    The test set is resampled with replacement n_boot times and every metric
    is recomputed each time. The SAME resampled rows are used for all four
    models in each round (a paired bootstrap), so "ensemble minus XGBoost"
    is measured on identical patients. If the 95% interval of that difference
    excludes 0, the difference is real; if it includes 0, it could be noise.

    Nothing is retrained: thresholds/class weights stay the ones learned
    from training data, only the test patients are resampled.
    """
    n_boot = n_boot or config.N_BOOTSTRAP
    seed = config.RANDOM_STATE if seed is None else seed
    y = np.asarray(y_test)
    th = getattr(model, "thresholds_", {})
    cw = getattr(model, "class_weights_", {})
    probas = {"stacked_ensemble": model.predict_proba(X_test), **model.base_predict_proba(X_test)}
    preds = {n: decide(p, th.get(n), cw.get(n)) for n, p in probas.items()}
    binary = probas["stacked_ensemble"].shape[1] == 2
    k = probas["stacked_ensemble"].shape[1]

    rng = np.random.default_rng(seed)
    draws = {n: [] for n in probas}
    for _ in range(n_boot):
        idx = rng.integers(0, len(y), len(y))
        if len(np.unique(y[idx])) < k:      # a class vanished from this sample: AUC undefined
            continue
        for n in probas:
            draws[n].append(_core_metrics(y[idx], probas[n][idx], preds[n][idx], binary))

    metrics = [m for m in CI_METRICS if m in draws["stacked_ensemble"][0]]
    arr = {n: {m: np.array([d[m] for d in draws[n]]) for m in metrics} for n in draws}
    out = {"n_boot": len(draws["stacked_ensemble"]),
           "models": {n: {m: _ci(arr[n][m]) for m in metrics} for n in arr},
           "ensemble_minus": {}}
    for n in arr:
        if n == "stacked_ensemble":
            continue
        out["ensemble_minus"][n] = {}
        for m in metrics:
            lo, hi = _ci(arr["stacked_ensemble"][m] - arr[n][m])
            verdict = ("ensemble better" if lo > 0 else
                       "ensemble worse" if hi < 0 else "no clear difference")
            out["ensemble_minus"][n][m] = {"diff_ci": [lo, hi], "verdict": verdict}
    return out


def print_ci(title: str, results: dict, ci: dict):
    metrics = [m for m in CI_METRICS if m in ci["models"]["stacked_ensemble"]]
    print(f"\n  {title} - 95% confidence intervals ({ci['n_boot']} bootstrap samples)")
    print("  " + f"{'model':18s}" + "".join(f"{m:>22s}" for m in metrics))
    for n, mci in ci["models"].items():
        cells = [f"{results[n][m]:.3f} [{mci[m][0]:.3f}-{mci[m][1]:.3f}]" for m in metrics]
        print("  " + f"{n:18s}" + "".join(f"{c:>22s}" for c in cells))
    print("\n  ensemble minus ... (95% CI of the difference)")
    for n, diffs in ci["ensemble_minus"].items():
        parts = [f"{m} {d['diff_ci'][0]:+.3f}..{d['diff_ci'][1]:+.3f} ({d['verdict']})"
                 for m, d in diffs.items() if m in ("f1", "roc_auc", "pr_auc")]
        print(f"    vs {n:14s} " + " | ".join(parts))


def print_summary(title: str, results: dict):
    keys = ["accuracy", "balanced_accuracy", "precision", "recall", "f1", "roc_auc", "pr_auc"]
    print(f"\n  {title}")
    print("  " + f"{'model':18s}" + "".join(f"{k[:9]:>10s}" for k in keys))
    for name, m in results.items():
        print("  " + f"{name:18s}" + "".join(f"{m.get(k, float('nan')):10.4f}" for k in keys))


# ---------------------------------------------------------------- calibration
def calibration_metrics(y_true, p, n_bins=10) -> dict:
    """Can the predicted % be read as a real-world chance? (binary, p = P(disease)).

    brier          mean squared error of the probability (lower is better)
    brier_baseline Brier of always predicting the dataset's disease rate;
                   a useful model must beat this
    ece            expected calibration error: average gap between predicted %
                   and actual % across equal-sized bins (0 = perfect)
    bins           the reliability table: each bin's mean predicted vs actual rate
    """
    y = np.asarray(y_true).astype(int)
    p = np.asarray(p, dtype=float)
    rate = y.mean()
    # Equal-count bins (deciles of the predictions); empty bins are skipped
    order = np.argsort(p, kind="stable")
    bins, ece = [], 0.0
    for idx in np.array_split(order, n_bins):
        if len(idx) == 0:
            continue
        pred, actual = p[idx].mean(), y[idx].mean()
        ece += abs(pred - actual) * len(idx) / len(y)
        bins.append({"n": int(len(idx)), "predicted": round(float(pred), 4),
                     "actual": round(float(actual), 4)})
    return {"rate": round(float(rate), 4), "mean_predicted": round(float(p.mean()), 4),
            "brier": round(float(np.mean((p - y) ** 2)), 4),
            "brier_baseline": round(float(np.mean((rate - y) ** 2)), 4),
            "ece": round(float(ece), 4), "bins": bins}
