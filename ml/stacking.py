import time

import numpy as np
import pandas as pd
from imblearn.combine import SMOTETomek
from imblearn.over_sampling import SMOTE
from imblearn.under_sampling import TomekLinks
from lightgbm import LGBMClassifier
from sklearn.base import BaseEstimator, ClassifierMixin, clone
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.metrics import f1_score, precision_recall_curve
from sklearn.model_selection import StratifiedKFold, cross_val_predict
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import Pipeline, make_pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from xgboost import XGBClassifier

from ml import config

def best_threshold(y, p, mode=None, min_recall=None):
    """Pick a yes/no cut-off from probabilities p for true labels y (binary only)."""
    mode = mode or config.THRESHOLD_MODE
    min_recall = config.MIN_RECALL if min_recall is None else min_recall
    precision, recall, thresholds = precision_recall_curve(y, p)
    # precision/recall have one extra trailing value that has no threshold
    precision, recall = precision[:-1], recall[:-1]
    if mode == "f1":
        f1 = 2 * precision * recall / (precision + recall + 1e-12)
        i = int(np.argmax(f1))
    else:  # "recall"
        ok = np.where(recall >= min_recall)[0]
        i = int(ok[np.argmax(precision[ok])])
    return float(thresholds[i])


def best_class_weights(y, proba, grid=None, passes=3):
    """Per-class multipliers for multi-class predictions, chosen to maximise macro-F1.

    Prediction becomes argmax(proba * weights). Binary targets use a threshold;
    multi-class targets (Diabetes_012) use these weights instead.
    """
    grid = np.geomspace(0.5, 50, 40) if grid is None else grid
    k = proba.shape[1]
    w = np.ones(k)

    def score(weights):
        return f1_score(y, (proba * weights).argmax(axis=1), average="macro", zero_division=0)

    best = score(w)
    for _ in range(passes):
        for c in range(1, k):            # class 0 stays at 1: only the ratios matter
            for v in grid:
                trial = w.copy()
                trial[c] = v
                s = score(trial)
                if s > best:
                    best, w = s, trial
    return w

def make_preprocessor(numeric: list, categorical: list) -> ColumnTransformer:
    parts = []
    if numeric:
        parts.append(("num", SimpleImputer(strategy="median"), numeric))
    if categorical:
        parts.append(("cat", Pipeline([
            ("impute", SimpleImputer(strategy="most_frequent")),
            ("onehot", OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
        ]), categorical))
    return ColumnTransformer(parts, remainder="drop", verbose_feature_names_out=False)


def make_base_learners() -> dict:
    return {
        "xgboost": XGBClassifier(**config.XGB_PARAMS),
        "random_forest": RandomForestClassifier(**config.RF_PARAMS),
        "knn": make_pipeline(StandardScaler(), KNeighborsClassifier(**config.KNN_PARAMS)),
    }


def minority_strategy(y: np.ndarray, ratio: float) -> dict:
    classes, counts = np.unique(y, return_counts=True)
    n_major = counts.max()
    target = {}
    for c, n in zip(classes, counts):
        want = int(ratio * n_major)
        if n < n_major and want > n:
            target[c] = want
    return target


def resample(X: np.ndarray, y: np.ndarray, ratio: float, seed: int):
    strategy = minority_strategy(y, ratio)
    if not strategy:
        return X, y
    smallest = min(np.bincount(y)[np.bincount(y) > 0])
    smote = SMOTE(sampling_strategy=strategy, k_neighbors=max(1, min(5, smallest - 1)),
                  random_state=seed)
    sampler = SMOTETomek(smote=smote, tomek=TomekLinks(n_jobs=-1), random_state=seed)
    return sampler.fit_resample(X, y)


class StackedEnsemble(ClassifierMixin, BaseEstimator):

    def __init__(self, numeric=None, categorical=None, use_resampling=True,
                 minority_ratio=config.MINORITY_RATIO, cv_folds=config.CV_FOLDS,
                 random_state=config.RANDOM_STATE, verbose=True):
        self.numeric = numeric
        self.categorical = categorical
        self.use_resampling = use_resampling
        self.minority_ratio = minority_ratio
        self.cv_folds = cv_folds
        self.random_state = random_state
        self.verbose = verbose

    # -- helpers -------------------------------------------------------------
    def _log(self, msg):
        if self.verbose:
            print(f"    [{time.strftime('%H:%M:%S')}] {msg}", flush=True)

    def _fit_bases(self, X, y):
        fitted = {}
        for name, est in make_base_learners().items():
            t = time.time()
            fitted[name] = clone(est).fit(X, y)
            self._log(f"  fitted {name:13s} ({time.time() - t:.0f}s)")
        return fitted

    def _meta_features(self, bases: dict, X: np.ndarray) -> np.ndarray:
        cols = []
        for name in bases:
            p = bases[name].predict_proba(X)
            # Binary: the two columns sum to 1, keep only P(class 1)
            cols.append(p[:, 1:] if p.shape[1] == 2 else p)
        return np.hstack(cols)

    def _prepare_y(self, y):
        y = np.asarray(y).astype(int)
        self.classes_ = np.unique(y)
        if not np.array_equal(self.classes_, np.arange(len(self.classes_))):
            raise ValueError("Labels must be 0..k-1 (required by XGBoost).")
        return y

    # -- sklearn API ---------------------------------------------------------
    def fit(self, X: pd.DataFrame, y):
        y = self._prepare_y(y)
        numeric = list(self.numeric or [])
        categorical = list(self.categorical or [])
        self.feature_names_in_ = np.array(numeric + categorical, dtype=object)
        X = X[numeric + categorical]

        # 1) Out-of-fold predictions for the meta-learner
        skf = StratifiedKFold(n_splits=self.cv_folds, shuffle=True,
                              random_state=self.random_state)
        oof = None
        for k, (tr, va) in enumerate(skf.split(X, y), start=1):
            self._log(f"fold {k}/{self.cv_folds}")
            prep = make_preprocessor(numeric, categorical).fit(X.iloc[tr])
            Xtr, ytr = prep.transform(X.iloc[tr]), y[tr]
            if self.use_resampling:
                n0 = len(ytr)
                Xtr, ytr = resample(Xtr, ytr, self.minority_ratio, self.random_state + k)
                self._log(f"  SMOTE-Tomek {n0:,} -> {len(ytr):,} rows, "
                          f"classes {np.bincount(ytr).tolist()}")
            bases = self._fit_bases(Xtr, ytr)
            mf = self._meta_features(bases, prep.transform(X.iloc[va]))
            if oof is None:
                oof = np.zeros((len(y), mf.shape[1]))
            oof[va] = mf

        # 2) Meta-learner trained on the honest OOF predictions.
        #    No class weighting: the base learners already saw balanced data,
        #    and the OOF rows keep the real class ratio, so the meta-learner
        #    also calibrates the probabilities back to realistic values.
        #    Recall is handled by the decision thresholds below instead.
        self._log("fitting LightGBM meta-learner")
        self.meta_ = LGBMClassifier(**config.META_PARAMS).fit(oof, y)

        # 3) Final base learners refit on the full training set
        self._log("refitting base learners on full training set")
        self.preprocessor_ = make_preprocessor(numeric, categorical).fit(X)
        Xall, yall = self.preprocessor_.transform(X), y
        if self.use_resampling:
            Xall, yall = resample(Xall, yall, self.minority_ratio, self.random_state)
        self.bases_ = self._fit_bases(Xall, yall)
        self.oof_meta_features_ = oof

        # Honest out-of-fold probabilities for the ensemble itself
        # (used only to choose its threshold, never for training)
        oof_ensemble = self._oof_ensemble(oof, y)
        self.tune_thresholds(y, oof_ensemble=oof_ensemble)

        # Multi-class targets: per-class weights instead of a threshold.
        # For k classes each base learner contributes k OOF columns, in the
        # order of make_base_learners(), so learner i is columns i*k..(i+1)*k
        self.class_weights_ = {}
        k = len(self.classes_)
        if k > 2:
            self.class_weights_["stacked_ensemble"] = best_class_weights(y, oof_ensemble)
            for i, name in enumerate(make_base_learners()):
                self.class_weights_[name] = best_class_weights(y, oof[:, i * k:(i + 1) * k])
            self._log("class weights: " + ", ".join(
                f"{n} {np.round(w, 2).tolist()}" for n, w in self.class_weights_.items()))
        return self

    def _oof_ensemble(self, oof, y):
        """Out-of-fold probabilities of the meta-learner (cross-validated on the OOF table)."""
        meta_cv = StratifiedKFold(n_splits=self.cv_folds, shuffle=True,
                                  random_state=self.random_state + 100)
        return cross_val_predict(LGBMClassifier(**config.META_PARAMS), oof, y,
                                 cv=meta_cv, method="predict_proba")

    def tune_thresholds(self, y, mode=None, min_recall=None, oof_ensemble=None):
        """Choose one decision threshold per model (binary targets only).

        Uses only the stored training out-of-fold predictions, so it can be
        re-run on a saved model with a different mode ("f1" or "recall")
        without retraining. y must be the training labels the model was fit on.
        """
        oof = self.oof_meta_features_
        y = np.asarray(y).astype(int)
        self.thresholds_ = {}
        if len(self.classes_) != 2:
            return self
        if oof_ensemble is None:
            oof_ensemble = self._oof_ensemble(oof, y)
        # One threshold per model, all chosen the same way -> fair comparison
        self.thresholds_["stacked_ensemble"] = best_threshold(y, oof_ensemble[:, 1], mode, min_recall)
        for i, name in enumerate(make_base_learners()):
            self.thresholds_[name] = best_threshold(y, oof[:, i], mode, min_recall)
        return self

    def predict_proba(self, X: pd.DataFrame) -> np.ndarray:
        Xt = self.preprocessor_.transform(X[list(self.feature_names_in_)])
        return self.meta_.predict_proba(self._meta_features(self.bases_, Xt))

    def predict(self, X: pd.DataFrame) -> np.ndarray:
        proba = self.predict_proba(X)
        # Binary targets use the tuned threshold, multi-class (Diabetes_012)
        # uses the tuned class weights; older saved models fall back to argmax
        t = getattr(self, "thresholds_", {}).get("stacked_ensemble")
        if t is not None:
            return (proba[:, 1] >= t).astype(int)
        w = getattr(self, "class_weights_", {}).get("stacked_ensemble")
        if w is not None:
            return self.classes_[(proba * w).argmax(axis=1)]
        return self.classes_[proba.argmax(axis=1)]

    def base_predict_proba(self, X: pd.DataFrame) -> dict:
        Xt = self.preprocessor_.transform(X[list(self.feature_names_in_)])
        return {name: est.predict_proba(Xt) for name, est in self.bases_.items()}
