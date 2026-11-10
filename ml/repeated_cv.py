"""Repeated cross-validation: a fairer ensemble-vs-single-model comparison on SMALL datasets.

The 80:20 split gives heart only 184 test patients and stroke only 50 stroke
cases, so one lucky or unlucky split can decide which model "wins". Here every
model is trained and tested 25 times (5 folds x 5 repeats), each time on a
different split of the WHOLE dataset, and we report mean +/- SD.

    python -m ml.repeated_cv --layer2 heart stroke      (~5 min)
    python -m ml.repeated_cv --layer2 all               (+ diabetes, ~25 min)

Inside every round the full pipeline runs exactly as in training (in-fold
SMOTE-Tomek, out-of-fold meta-features, thresholds chosen from that round's
training data only), so no test patient ever influences its own prediction.

"Is the ensemble really better?" uses the corrected resampled t-test
(Nadeau & Bengio, 2003). Ordinary t-tests on CV folds are over-confident
because the 25 training sets overlap; the correction accounts for that.
p < 0.05 -> the difference is unlikely to be chance.

Results: ml/reports/layer2_<name>_repeated_cv.json (summary + every round).
The saved models in ml/models/ are NOT touched.
"""
import argparse
import json
import time

import numpy as np
from scipy import stats
from sklearn.model_selection import RepeatedStratifiedKFold

from ml import config
from ml.data import load_layer2
from ml.evaluate import calibration_metrics, classification_metrics
from ml.stacking import StackedEnsemble

METRICS = ["f1", "recall", "precision", "balanced_accuracy", "roc_auc", "pr_auc", "brier"]
HIGHER_IS_BETTER = {m: m != "brier" for m in METRICS}


def one_round(spec, X_tr, y_tr, X_te, y_te) -> dict:
    """Train the full ensemble on one fold and score it and its 3 base learners."""
    model = StackedEnsemble(numeric=spec["numeric"], categorical=spec["categorical"],
                            use_resampling=spec["resample"], verbose=False).fit(X_tr, y_tr)
    probas = {"stacked_ensemble": model.predict_proba(X_te), **model.base_predict_proba(X_te)}
    out = {}
    for name, proba in probas.items():
        m = classification_metrics(y_te, proba, model.thresholds_.get(name))
        m["brier"] = calibration_metrics(y_te, proba[:, 1])["brier"]
        out[name] = {k: m[k] for k in METRICS}
    return out


def corrected_ttest(diffs, n_train, n_test) -> float:
    """Two-sided p-value of the Nadeau-Bengio corrected resampled t-test."""
    d = np.asarray(diffs, dtype=float)
    var = d.var(ddof=1)
    if var == 0:
        return 1.0 if d.mean() == 0 else 0.0
    t = d.mean() / np.sqrt((1 / len(d) + n_test / n_train) * var)
    return float(2 * stats.t.sf(abs(t), df=len(d) - 1))


def summarise(rounds, n_train, n_test) -> dict:
    models = list(rounds[0])
    summary = {"models": {}, "ensemble_vs": {}}
    for name in models:
        summary["models"][name] = {
            m: {"mean": round(float(np.mean([r[name][m] for r in rounds])), 4),
                "sd": round(float(np.std([r[name][m] for r in rounds], ddof=1)), 4)}
            for m in METRICS}
    for name in models[1:]:
        summary["ensemble_vs"][name] = {}
        for m in METRICS:
            diffs = [r["stacked_ensemble"][m] - r[name][m] for r in rounds]
            better = [d > 0 if HIGHER_IS_BETTER[m] else d < 0 for d in diffs]
            p = corrected_ttest(diffs, n_train, n_test)
            mean = float(np.mean(diffs))
            ens_better = mean > 0 if HIGHER_IS_BETTER[m] else mean < 0
            verdict = ("no significant difference" if p >= 0.05 else
                       "ensemble significantly better" if ens_better else
                       "ensemble significantly worse")
            summary["ensemble_vs"][name][m] = {
                "mean_diff": round(mean, 4), "ensemble_wins": int(sum(better)),
                "rounds": len(diffs), "p_value": round(p, 4), "verdict": verdict}
    return summary


def print_summary(title, s):
    shown = ["f1", "recall", "roc_auc", "pr_auc", "brier"]
    print(f"\n  {title} - mean +/- SD over the rounds")
    print("  " + f"{'model':18s}" + "".join(f"{m:>17s}" for m in shown))
    for name, ms in s["models"].items():
        print("  " + f"{name:18s}" + "".join(
            f"{ms[m]['mean']:>10.3f} +/-{ms[m]['sd']:.3f}" for m in shown))
    print("\n  ensemble vs ...   (mean difference, rounds won, corrected t-test p)")
    for name, ms in s["ensemble_vs"].items():
        for m in ["f1", "roc_auc", "pr_auc"]:
            d = ms[m]
            print(f"    vs {name:14s} {m:8s} {d['mean_diff']:+.3f}  won {d['ensemble_wins']:2d}/"
                  f"{d['rounds']}  p={d['p_value']:.3f}  -> {d['verdict']}")


def run(name, folds, repeats):
    spec = config.LAYER2[name]
    X, y = load_layer2(name)
    y = y.to_numpy()
    cv = RepeatedStratifiedKFold(n_splits=folds, n_repeats=repeats,
                                 random_state=config.RANDOM_STATE)
    total = folds * repeats
    print(f"\n=== layer2_{name}: {len(X):,} rows, {y.mean():.1%} positive | "
          f"{folds} folds x {repeats} repeats = {total} rounds")
    t0, rounds = time.time(), []
    for i, (tr, te) in enumerate(cv.split(X, y), 1):
        rounds.append(one_round(spec, X.iloc[tr], y[tr], X.iloc[te], y[te]))
        e = rounds[-1]["stacked_ensemble"]
        print(f"    round {i:2d}/{total}  ensemble F1 {e['f1']:.3f}  AUC {e['roc_auc']:.3f}  "
              f"({time.time() - t0:.0f}s)", flush=True)

    n_test = len(y) // folds
    s = summarise(rounds, n_train=len(y) - n_test, n_test=n_test)
    print_summary(f"layer2_{name}", s)
    out = {"model": f"layer2_{name}", "rows": len(y), "folds": folds, "repeats": repeats,
           "smote_tomek": spec["resample"], **s, "rounds": rounds,
           "seconds": round(time.time() - t0)}
    config.REPORTS.mkdir(parents=True, exist_ok=True)
    dest = config.REPORTS / f"layer2_{name}_repeated_cv.json"
    dest.write_text(json.dumps(out, indent=2))
    print(f"\n  saved {dest.relative_to(config.ROOT)} ({time.time() - t0:.0f}s)")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--layer2", nargs="+", choices=list(config.LAYER2) + ["all"], required=True)
    ap.add_argument("--folds", type=int, default=5)
    ap.add_argument("--repeats", type=int, default=5)
    args = ap.parse_args()
    names = list(config.LAYER2) if "all" in args.layer2 else args.layer2
    for name in names:
        run(name, args.folds, args.repeats)


if __name__ == "__main__":
    np.random.seed(config.RANDOM_STATE)
    main()
