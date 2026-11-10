"""Calibration of models that are ALREADY trained: can the % shown in the app be trusted?

No retraining: loads the saved .joblib, rebuilds exactly the same 80:20 test
set as training, and compares the predicted risk % with what really happened.

    python -m ml.calibration --layer1 --layer2 all     (~10 min, mostly loading Model 1)
    python -m ml.calibration --layer2 heart stroke     (seconds)

For each disease it saves the numbers to ml/reports/*_calibration.json and a
reliability plot to ml/reports/figures/ (for Chapter 4):
- dots on the diagonal  = the % is honest ("40%" really means 4 in 10)
- dots below            = the model overstates the risk
- dots above            = the model understates the risk

The risk % is computed exactly as the API does (backend/app/main.py):
P(disease), and for Diabetes_012 P(prediabetes or diabetes) = 1 - P(none).
"""
import argparse
import json
import time

import joblib
import matplotlib
matplotlib.use("Agg")                    # draw to files, no window
import matplotlib.pyplot as plt
import numpy as np

from ml import config
from ml.evaluate import calibration_metrics
from ml.train import layer1_split, layer2_split

FIGURES = config.REPORTS / "figures"


def risk(proba: np.ndarray) -> np.ndarray:
    """Probability of 'has the disease' = 1 - P(class 0), as shown in the app."""
    return 1 - proba[:, 0]


def plot(title: str, cal: dict, dest):
    pred = [b["predicted"] * 100 for b in cal["bins"]]
    actual = [b["actual"] * 100 for b in cal["bins"]]
    top = max(max(pred), max(actual)) * 1.1
    fig, ax = plt.subplots(figsize=(4.5, 4.5))
    ax.plot([0, top], [0, top], ls="--", color="grey", lw=1, label="perfect calibration")
    ax.plot(pred, actual, marker="o", color="#1FA672", label="stacked ensemble")
    ax.set(xlim=(0, top), ylim=(0, top), xlabel="Predicted risk (%)", ylabel="Actual rate (%)",
           title=f"{title}\nECE {cal['ece']:.3f} | Brier {cal['brier']:.3f} "
                 f"(baseline {cal['brier_baseline']:.3f})")
    ax.title.set_fontsize(9)
    ax.legend(loc="upper left", fontsize=8)
    fig.tight_layout()
    fig.savefig(dest, dpi=150)
    plt.close(fig)


def report(name: str, title: str, y_true, proba) -> dict:
    y = (np.asarray(y_true) > 0).astype(int)     # any disease class counts as "has it"
    cal = calibration_metrics(y, risk(proba))
    dest = FIGURES / f"{name}_reliability.png"
    plot(title, cal, dest)
    verdict = "beats" if cal["brier"] < cal["brier_baseline"] else "does NOT beat"
    print(f"\n  {title}: rate {cal['rate']:.1%}, mean predicted {cal['mean_predicted']:.1%}, "
          f"ECE {cal['ece']:.3f}, Brier {cal['brier']:.4f} ({verdict} baseline "
          f"{cal['brier_baseline']:.4f})")
    for b in cal["bins"]:
        print(f"      predicted {b['predicted']:6.1%} -> actual {b['actual']:6.1%}  (n={b['n']})")
    print(f"    plot: {dest.relative_to(config.ROOT)}")
    return cal


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--layer1", action="store_true")
    ap.add_argument("--layer2", nargs="+", choices=list(config.LAYER2) + ["all"])
    ap.add_argument("--sample", type=int, default=None, help="use the *_dev<N> models")
    args = ap.parse_args()
    if not args.layer1 and not args.layer2:
        ap.error("choose --layer1 and/or --layer2")
    suffix = f"_dev{args.sample}" if args.sample else ""
    FIGURES.mkdir(parents=True, exist_ok=True)

    if args.layer1:
        t0 = time.time()
        model = joblib.load(config.MODELS / f"layer1_general{suffix}.joblib")
        _, X_te, _, Y_te = layer1_split(args.sample)
        # one predict_proba call returns one probability array per disease
        out = {t: report(f"layer1_{t}{suffix}", f"Model 1 - {t}", Y_te[t], p)
               for t, p in zip(config.BRFSS_TARGETS, model.predict_proba(X_te))}
        dest = config.REPORTS / f"layer1_general{suffix}_calibration.json"
        dest.write_text(json.dumps(out, indent=2))
        print(f"\n  saved {dest.relative_to(config.ROOT)} ({time.time() - t0:.0f}s)")

    if args.layer2:
        names = list(config.LAYER2) if "all" in args.layer2 else args.layer2
        for name in names:
            model = joblib.load(config.MODELS / f"layer2_{name}{suffix}.joblib")
            _, X_te, _, y_te = layer2_split(name, args.sample)
            out = report(f"layer2_{name}{suffix}", f"Deep check - {name}", y_te,
                         model.predict_proba(X_te))
            dest = config.REPORTS / f"layer2_{name}{suffix}_calibration.json"
            dest.write_text(json.dumps(out, indent=2))
            print(f"  saved {dest.relative_to(config.ROOT)}")


if __name__ == "__main__":
    main()
