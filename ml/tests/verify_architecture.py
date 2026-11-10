"""Check that the training code behaves like Figure 3.8 (AI Model Architecture).

Run from the repo root with the venv active (takes about 1 minute):
    python -m ml.tests.verify_architecture

It trains small models and records every SMOTE-Tomek call to prove:
the 80:20 split, SMOTE-Tomek only inside each CV fold's training part (never
the test set), conditional resampling, XGBoost + RF + KNN (scaler on KNN
only) -> LightGBM meta-learner, and Model 1 as one multi-output model.
Rerun it after any change to ml/stacking.py, ml/train.py or ml/config.py.
"""
import contextlib
import io

import numpy as np
from lightgbm import LGBMClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.multioutput import MultiOutputClassifier
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from xgboost import XGBClassifier

import ml.stacking as S
from ml import config
from ml.data import load_brfss, load_layer2

# Record every SMOTE-Tomek call (row counts before/after) without changing its behaviour
calls = []
_original_resample = S.resample


def _spy(X, y, ratio, seed):
    Xr, yr = _original_resample(X, y, ratio, seed)
    calls.append({"in": len(y), "out": len(yr),
                  "in_counts": np.bincount(y).tolist(), "out_counts": np.bincount(yr).tolist()})
    return Xr, yr


S.resample = _spy
results = []


def check(cond, msg):
    results.append(cond)
    print(("  PASS  " if cond else "  FAIL  ") + msg)


def quiet(fn, *args):
    with contextlib.redirect_stdout(io.StringIO()):
        return fn(*args)


def split(X, y):
    return train_test_split(X, y, test_size=config.TEST_SIZE, stratify=y,
                            random_state=config.RANDOM_STATE)


def layer2_stroke():
    print("\n[Layer 2 - stroke, SMOTE-Tomek ON]")
    spec = config.LAYER2["stroke"]
    X, y = load_layer2("stroke")
    y = y.to_numpy()
    X_tr, X_te, y_tr, _ = split(X, y)
    calls.clear()
    m = quiet(S.StackedEnsemble(numeric=spec["numeric"], categorical=spec["categorical"],
                                use_resampling=True).fit, X_tr, y_tr)

    share = len(X_te) / len(X)
    check(len(X_tr) + len(X_te) == len(X) and round(share, 2) == config.TEST_SIZE,
          f"80:20 split: {len(X_tr)} train / {len(X_te)} test ({share:.1%})")
    check(len(calls) == config.CV_FOLDS + 1,
          f"SMOTE-Tomek ran {len(calls)}x ({config.CV_FOLDS} folds + 1 final refit)")
    fold_in = [c["in"] for c in calls[:config.CV_FOLDS]]
    expected = len(X_tr) * (config.CV_FOLDS - 1) / config.CV_FOLDS
    check(all(abs(n - expected) <= 1 for n in fold_in),
          f"each fold resampled only its training part: {fold_in} (~80% of {len(X_tr)})")
    check(calls[-1]["in"] == len(X_tr), f"final refit resampled the full training set: {calls[-1]['in']}")
    check(len(X_te) not in [c["in"] for c in calls], "test set never passed to SMOTE-Tomek")
    print(f"         fold 1 class counts {calls[0]['in_counts']} -> {calls[0]['out_counts']} "
          f"(SMOTE up to {config.MINORITY_RATIO:.0%} of majority, Tomek trims borderline rows)")

    b = m.bases_
    check(isinstance(b["xgboost"], XGBClassifier) and isinstance(b["random_forest"], RandomForestClassifier),
          "base learners include XGBoost and Random Forest")
    knn = b["knn"]
    check(isinstance(knn, Pipeline) and isinstance(knn.steps[0][1], StandardScaler)
          and isinstance(knn.steps[-1][1], KNeighborsClassifier),
          "KNN base learner = StandardScaler -> KNN")
    check(not isinstance(b["xgboost"], Pipeline) and not isinstance(b["random_forest"], Pipeline),
          "XGBoost / Random Forest have no scaler")
    check(isinstance(m.meta_, LGBMClassifier) and m.meta_.n_features_in_ == 3,
          f"meta-learner is LightGBM with {m.meta_.n_features_in_} inputs (1 probability x 3 base learners)")
    check(m.oof_meta_features_.shape == (len(X_tr), 3),
          f"out-of-fold table covers every training row: {m.oof_meta_features_.shape}")
    n_before = len(calls)
    m.predict_proba(X_te)
    check(len(calls) == n_before, "prediction on the 20% test set does no resampling")


def layer2_heart():
    print("\n[Layer 2 - heart, SMOTE-Tomek OFF (conditional)]")
    spec = config.LAYER2["heart"]
    X, y = load_layer2("heart")
    X_tr, _, y_tr, _ = split(X, y.to_numpy())
    calls.clear()
    m = quiet(S.StackedEnsemble(numeric=spec["numeric"], categorical=spec["categorical"],
                                use_resampling=spec["resample"]).fit, X_tr, y_tr)
    check(not spec["resample"] and len(calls) == 0, "SMOTE-Tomek skipped for the balanced heart dataset")
    check(isinstance(m.meta_, LGBMClassifier) and len(m.bases_) == 3,
          "still a full stack: 3 base learners -> LightGBM")


def layer1():
    print("\n[Layer 1 - Model 1, one MultiOutputClassifier, 3000-row sample]")
    X, Y = load_brfss()
    X, _, Y, _ = train_test_split(X, Y, train_size=3000, stratify=Y["Diabetes_012"],
                                  random_state=config.RANDOM_STATE)
    X_tr, X_te, Y_tr, _ = train_test_split(X, Y, test_size=config.TEST_SIZE,
                                           stratify=Y["Diabetes_012"], random_state=config.RANDOM_STATE)
    calls.clear()
    m = quiet(MultiOutputClassifier(S.StackedEnsemble(numeric=config.BRFSS_FEATURES,
                                                      categorical=[])).fit, X_tr, Y_tr.to_numpy())
    check(len(m.estimators_) == 3, "one model object holding 3 per-disease ensembles")
    check(len(calls) == 3 * (config.CV_FOLDS + 1),
          f"SMOTE-Tomek ran {len(calls)}x ({config.CV_FOLDS + 1} per disease x 3)")
    dims = [e.meta_.n_features_in_ for e in m.estimators_]
    check(dims == [9, 3, 3], f"meta-learner inputs per disease {dims} (diabetes is 3-class: 3x3=9)")
    out = m.predict_proba(X_te.iloc[:1])
    check(len(out) == 3 and [o.shape[1] for o in out] == [3, 2, 2],
          "one predict_proba call returns 3 outputs: diabetes(3), heart(2), stroke(2)")


if __name__ == "__main__":
    layer2_stroke()
    layer2_heart()
    layer1()
    passed = all(results)
    print(f"\n{sum(results)}/{len(results)} checks passed -> "
          + ("ALL CHECKS PASSED" if passed else "SOME CHECKS FAILED"))
    raise SystemExit(0 if passed else 1)
