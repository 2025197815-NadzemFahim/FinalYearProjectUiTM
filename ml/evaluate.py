import numpy as np
from sklearn.metrics import (accuracy_score, average_precision_score,
                             balanced_accuracy_score, confusion_matrix,
                             f1_score, precision_score, recall_score,
                             roc_auc_score)


def classification_metrics(y_true, proba: np.ndarray) -> dict:
    y_true = np.asarray(y_true)
    y_pred = proba.argmax(axis=1)
    binary = proba.shape[1] == 2
    avg = "binary" if binary else "macro"
    m = {
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
    results = {"stacked_ensemble": classification_metrics(y_test, model.predict_proba(X_test))}
    for name, proba in model.base_predict_proba(X_test).items():
        results[name] = classification_metrics(y_test, proba)
    return results


def print_summary(title: str, results: dict):
    keys = ["accuracy", "balanced_accuracy", "precision", "recall", "f1", "roc_auc"]
    print(f"\n  {title}")
    print("  " + f"{'model':18s}" + "".join(f"{k[:9]:>10s}" for k in keys))
    for name, m in results.items():
        print("  " + f"{name:18s}" + "".join(f"{m.get(k, float('nan')):10.4f}" for k in keys))
