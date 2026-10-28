"""Train a Layer 2 model with YOUR settings and save it in the registry (never overwrites).

    python -m ml.experiment --disease heart
    python -m ml.experiment --disease heart --set xgboost.max_depth=4 --set meta.num_leaves=7
    python -m ml.experiment --disease heart --role reduced          # no stress-test readings
    python -m ml.experiment --disease stroke --params-file my_settings.json --note "deeper RF"
    python -m ml.experiment --disease stroke --set knn.n_neighbors=31 --no-save   # score only

--set takes <learner>.<setting>=<value>, learner = xgboost | random_forest | knn | meta.
Anything you don't set keeps its config.py value.

What happens:
1. The SAME 80:20 split as ml.train. The 20% test set is locked away.
2. Cross-validation on the 80% training set only -> CV F1 (the score that picks the best model).
3. The final model is fitted on the whole training set and checked ONCE on the test set.
4. Saved to ml/models/registry/ under a new name + one row in ml/model_registry.csv.
   The API keeps using its current model until you approve a switch.
"""
import argparse
import json

import numpy as np
from sklearn.metrics import f1_score, roc_auc_score
from sklearn.model_selection import StratifiedKFold

from ml import config, registry
from ml.evaluate import compare_models, print_summary
from ml.stacking import StackedEnsemble
from ml.train import layer2_split


def features(disease: str, role: str) -> tuple[list, list]:
    if role == "full":
        spec = config.LAYER2[disease]
    else:
        spec = config.LAYER2_ROLES.get(disease, {}).get(role)
        if spec is None:
            raise SystemExit(f"no role '{role}' for {disease}; see config.LAYER2_ROLES")
    return spec["numeric"], spec["categorical"]


def make_model(disease, role, params, seed=config.RANDOM_STATE) -> StackedEnsemble:
    numeric, categorical = features(disease, role)
    return StackedEnsemble(numeric=numeric, categorical=categorical,
                           use_resampling=config.LAYER2[disease]["resample"],
                           random_state=seed, verbose=False, params=params)


def cv_score(disease, role, params, X_tr, y_tr, folds=5, seed=config.RANDOM_STATE) -> dict:
    """Mean/SD of the ensemble's F1 (at its own tuned threshold) and ROC-AUC over CV folds
    of the TRAINING data. Use this as the objective when tuning (e.g. inside Optuna)."""
    f1s, aucs = [], []
    cv = StratifiedKFold(n_splits=folds, shuffle=True, random_state=seed)
    for tr, va in cv.split(X_tr, y_tr):
        m = make_model(disease, role, params, seed).fit(X_tr.iloc[tr], y_tr[tr])
        p = m.predict_proba(X_tr.iloc[va])[:, 1]
        f1s.append(f1_score(y_tr[va], (p >= m.thresholds_["stacked_ensemble"]).astype(int)))
        aucs.append(roc_auc_score(y_tr[va], p))
    return {"cv_f1": float(np.mean(f1s)), "cv_f1_sd": float(np.std(f1s, ddof=1)),
            "cv_roc_auc": float(np.mean(aucs))}


def parse_sets(items) -> dict:
    """["xgboost.max_depth=4", "meta.num_leaves=7"] -> {"xgboost": {"max_depth": 4}, ...}"""
    out = {}
    for item in items or []:
        key, _, raw = item.partition("=")
        learner, _, setting = key.partition(".")
        if learner not in ("xgboost", "random_forest", "knn", "meta") or not setting or not raw:
            raise SystemExit(f"bad --set '{item}': use learner.setting=value")
        try:
            value = json.loads(raw)            # 4 -> int, 0.1 -> float, true -> bool
        except json.JSONDecodeError:
            value = raw                        # e.g. max_features=sqrt
        out.setdefault(learner, {})[setting] = value
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--disease", required=True, choices=list(config.LAYER2))
    ap.add_argument("--role", default="full")
    ap.add_argument("--set", action="append", metavar="LEARNER.SETTING=VALUE")
    ap.add_argument("--params-file", help="JSON file with the same shape as --set builds")
    ap.add_argument("--folds", type=int, default=5)
    ap.add_argument("--seed", type=int, default=config.RANDOM_STATE)
    ap.add_argument("--note", default="")
    ap.add_argument("--no-save", action="store_true", help="only log the CV score as a trial")
    args = ap.parse_args()

    params = json.loads(open(args.params_file).read()) if args.params_file else {}
    for learner, settings in parse_sets(args.set).items():
        params.setdefault(learner, {}).update(settings)
    numeric, categorical = features(args.disease, args.role)
    print(f"\n=== {args.disease} ({args.role}): {len(numeric + categorical)} readings | "
          f"settings changed: {params or 'none (config.py defaults)'}")

    X_tr, X_te, y_tr, y_te = layer2_split(args.disease)
    print(f"  cross-validation on the training set ({args.folds} folds)...", flush=True)
    cv = cv_score(args.disease, args.role, params, X_tr, y_tr, args.folds, args.seed)
    print(f"  CV F1 {cv['cv_f1']:.4f} +/- {cv['cv_f1_sd']:.4f} | CV ROC-AUC {cv['cv_roc_auc']:.4f}")

    if args.no_save:
        registry.log_trial(args.disease, args.role, params, seed=args.seed, note=args.note, **cv)
        print("  logged as a trial in ml/model_registry.csv (no model saved)")
        return

    print("  fitting the final model on the whole training set...", flush=True)
    model = make_model(args.disease, args.role, params, args.seed).fit(X_tr, y_tr)
    results = compare_models(model, X_te, y_te)
    print_summary(f"{args.disease} ({args.role}) - held-out test set", results)
    path = registry.save_final(model, args.disease, args.role, params, seed=args.seed,
                               test=results["stacked_ensemble"], note=args.note, **cv)
    best = [r for r in registry.read() if r["best"] == "yes" and r["disease"] == args.disease
            and r["role"] == args.role]
    print(f"\n  saved {registry.rel(path)}")
    if best:
        print(f"  best {args.disease} ({args.role}) so far: {best[0]['name']} "
              f"(CV F1 {best[0]['cv_f1']})")


if __name__ == "__main__":
    main()
