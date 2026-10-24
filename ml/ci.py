"""Bootstrap confidence intervals for models that are ALREADY trained.

No retraining: loads the saved .joblib, rebuilds exactly the same 80:20 test
set as training (shared split functions in ml/train.py), and checks that the
recomputed point scores match the saved report before trusting the result.

    python -m ml.ci --layer1                  # Model 1 (~9 min, 3 diseases)
    python -m ml.ci --layer2 all              # deep-check models (~2 min)
    python -m ml.ci --layer2 stroke --n-boot 200   # quicker, rougher

Compare models at a different decision rule, still without retraining:

    python -m ml.ci --layer1 --layer2 all --threshold-mode recall --min-recall 0.85

This re-chooses every binary model's threshold from its stored TRAINING
out-of-fold predictions (never the test set). Diabetes_012 keeps its class
weights. Results go to *_ci_recall85.json; the saved models are not changed.
"""
import argparse
import json
import time

import joblib
import numpy as np

from ml import config
from ml.train import evaluate_with_ci, layer1_split, layer2_split


def _check_matches_saved(name, target, results, suffix):
    """Same split + same model must reproduce the saved point scores exactly."""
    path = config.REPORTS / f"{name}{suffix}.json"
    if not path.exists():
        print(f"    (no saved report {path.name} to compare against)")
        return
    saved = json.loads(path.read_text())["results"]
    saved = saved[target] if target else saved
    a, b = results["stacked_ensemble"]["f1"], saved["stacked_ensemble"]["f1"]
    status = "matches saved report" if a == b else f"MISMATCH (saved {b}) - different split or model?"
    print(f"    ensemble F1 {a} -> {status}")


def _retune(est, y_train, mode, min_recall):
    """Re-choose thresholds from stored training OOF predictions. Binary only."""
    if len(est.classes_) != 2:
        print("    (multi-class target: keeps its tuned class weights)")
        return
    # Sanity check: recomputing the ORIGINAL rule must reproduce the stored
    # thresholds, proving we have the right training labels and OOF table
    stored = dict(est.thresholds_)
    est.tune_thresholds(y_train, mode="f1")
    same = all(np.isclose(est.thresholds_[n], stored[n]) for n in stored)
    print(f"    stored F1-mode thresholds reproduced: {'yes' if same else 'NO - check split'}")
    est.tune_thresholds(y_train, mode=mode, min_recall=min_recall)
    print("    new thresholds: " + ", ".join(f"{n} {t:.3f}" for n, t in est.thresholds_.items()))


def run(name, est, X_te, y_te, y_tr, target, suffix, args):
    title = f"{name} -> {target}" if target else name
    if args.threshold_mode:
        print(f"\n  [{title}] thresholds re-chosen: mode={args.threshold_mode}, "
              f"min_recall={args.min_recall}")
        _retune(est, y_tr, args.threshold_mode, args.min_recall)
        title += f" ({args.threshold_mode} mode)"
    results, ci = evaluate_with_ci(title, est, X_te, y_te, n_boot=args.n_boot)
    if not args.threshold_mode:
        _check_matches_saved(name, target, results, suffix)
    return {"results": results, "confidence_intervals": ci}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--layer1", action="store_true")
    ap.add_argument("--layer2", nargs="+", choices=list(config.LAYER2) + ["all"])
    ap.add_argument("--sample", type=int, default=None, help="use the *_dev<N> models")
    ap.add_argument("--n-boot", type=int, default=None, help=f"default {config.N_BOOTSTRAP}")
    ap.add_argument("--threshold-mode", choices=["f1", "recall"], default=None,
                    help="re-choose thresholds from training OOF predictions (no retraining)")
    ap.add_argument("--min-recall", type=float, default=config.MIN_RECALL,
                    help=f"target recall for --threshold-mode recall (default {config.MIN_RECALL})")
    args = ap.parse_args()
    if not args.layer1 and not args.layer2:
        ap.error("choose --layer1 and/or --layer2")
    suffix = f"_dev{args.sample}" if args.sample else ""
    tag = "" if not args.threshold_mode else (
        f"_{args.threshold_mode}{round(args.min_recall * 100)}" if args.threshold_mode == "recall"
        else f"_{args.threshold_mode}")
    config.REPORTS.mkdir(parents=True, exist_ok=True)

    if args.layer1:
        t0 = time.time()
        model = joblib.load(config.MODELS / f"layer1_general{suffix}.joblib")
        _, X_te, Y_tr, Y_te = layer1_split(args.sample)
        out = {}
        for target, est in zip(config.BRFSS_TARGETS, model.estimators_):
            out[target] = run("layer1_general", est, X_te, Y_te[target].to_numpy(),
                              Y_tr[target].to_numpy(), target, suffix, args)
        dest = config.REPORTS / f"layer1_general{suffix}_ci{tag}.json"
        dest.write_text(json.dumps(out, indent=2))
        print(f"\n  saved {dest.relative_to(config.ROOT)} ({time.time() - t0:.0f}s)")

    if args.layer2:
        names = list(config.LAYER2) if "all" in args.layer2 else args.layer2
        for name in names:
            t0 = time.time()
            model = joblib.load(config.MODELS / f"layer2_{name}{suffix}.joblib")
            _, X_te, y_tr, y_te = layer2_split(name, args.sample)
            out = run(f"layer2_{name}", model, X_te, y_te, y_tr, None, suffix, args)
            dest = config.REPORTS / f"layer2_{name}{suffix}_ci{tag}.json"
            dest.write_text(json.dumps(out, indent=2))
            print(f"\n  saved {dest.relative_to(config.ROOT)} ({time.time() - t0:.0f}s)")


if __name__ == "__main__":
    main()
