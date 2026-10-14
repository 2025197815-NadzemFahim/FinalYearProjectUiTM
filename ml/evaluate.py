import numpy as np
from sklearn.metrics import (accuracy_score, average_precision_score,
                             balanced_accuracy_score, confusion_matrix,
                             f1_score, precision_score, recall_score,
                             roc_auc_score)


def classification_metrics(y_true, proba: np.ndarray, threshold=None, class_weights=None) -> dict:
    y_true = np.asarray(y_true)
    binary = proba.shape[1] == 2
    # Binary: tuned threshold. Multi-class: tuned per-class weights.
    # Models without either (older saves) fall back to argmax.
    if binary and threshold is not None:
        y_pred = (proba[:, 1] >= threshold).astype(int)
    elif not binary and class_weights is not None:
        y_pred = (proba * np.asarray(class_weights)).argmax(axis=1)
    else:
        y_pred = proba.argmax(axis=1)
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


def print_summary(title: str, results: dict):
    keys = ["accuracy", "balanced_accuracy", "precision", "recall", "f1", "roc_auc", "pr_auc"]
    print(f"\n  {title}")
    print("  " + f"{'model':18s}" + "".join(f"{k[:9]:>10s}" for k in keys))
    for name, m in results.items():
        print("  " + f"{name:18s}" + "".join(f"{m.get(k, float('nan')):10.4f}" for k in keys))
