"""Model registry: never lose a trained model or a tuning result.

Every Layer 2 experiment is one row in ml/model_registry.csv (committed to git):
  kind = "trial"     one tuning try: settings + cross-validation score, no model file
  kind = "final"     a model fitted on the full training set and saved to ml/models/registry/
  kind = "baseline"  the models the API uses today (ml/models/layer2_*.joblib), for reference

Model files get a name that is never reused:
  layer2_{disease}_{role}_{algorithm}_{dataset-version}_f1-{cv F1}_{YYYYMMDD-HHMM}.joblib

"best" marks, per disease and role, the final model with the highest CROSS-VALIDATION F1.
The test score never picks the winner (that would be tuning to the test set).
Marking a model best does not change the API; switching the backend needs approval.

    python -m ml.registry list                  # every row
    python -m ml.registry list --disease heart  # one disease
    python -m ml.registry best                  # the best model per disease and role
    python -m ml.registry baselines             # register today's API models (once)
"""
import argparse
import csv
import hashlib
import json
import subprocess
import time
from pathlib import Path

import joblib

from ml import config

REGISTRY = config.ROOT / "ml" / "model_registry.csv"
MODEL_DIR = config.MODELS / "registry"
ALGORITHM = "stack-xgb-rf-knn-lgbm"
COLUMNS = ["timestamp", "kind", "disease", "role", "algorithm", "dataset_version", "dataset_md5",
           "seed", "git_commit", "cv_f1", "cv_f1_sd", "cv_roc_auc", "test_f1", "test_roc_auc",
           "test_pr_auc", "best", "name", "path", "params", "note"]


# ---------------------------------------------------------------- facts recorded in every row
def dataset_md5(disease: str) -> str:
    """Fingerprint of the raw data file: proves which data a model learned from."""
    return hashlib.md5(Path(config.LAYER2[disease]["file"]).read_bytes()).hexdigest()[:12]


def git_commit() -> str:
    """Short code version; '+dirty' means there were uncommitted changes when it ran."""
    try:
        sha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=config.ROOT,
                             capture_output=True, text=True).stdout.strip()
        dirty = subprocess.run(["git", "status", "--porcelain", "ml/"], cwd=config.ROOT,
                               capture_output=True, text=True).stdout.strip()
        return sha + ("+dirty" if dirty else "")
    except OSError:
        return "unknown"


def rel(path) -> str:
    """Path relative to the repo when inside it (portable), else absolute."""
    path = Path(path)
    return str(path.relative_to(config.ROOT)) if path.is_relative_to(config.ROOT) else str(path)


def _r(v):
    return "" if v is None else round(float(v), 4)


# ---------------------------------------------------------------- reading and writing the CSV
def read() -> list[dict]:
    if not REGISTRY.exists():
        return []
    with open(REGISTRY, newline="", encoding="utf8") as f:
        return list(csv.DictReader(f))


def _write(rows: list[dict]):
    with open(REGISTRY, "w", newline="", encoding="utf8") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS)
        w.writeheader()
        w.writerows(rows)


def _append(row: dict):
    new = not REGISTRY.exists()
    with open(REGISTRY, "a", newline="", encoding="utf8") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS)
        if new:
            w.writeheader()
        w.writerow({c: row.get(c, "") for c in COLUMNS})


def _base_row(kind, disease, role, params, seed, note) -> dict:
    return {"timestamp": time.strftime("%Y-%m-%d %H:%M:%S"), "kind": kind, "disease": disease,
            "role": role, "algorithm": ALGORITHM,
            "dataset_version": config.DATASET_VERSIONS[disease], "dataset_md5": dataset_md5(disease),
            "seed": seed, "git_commit": git_commit(),
            "params": json.dumps(params or {}, sort_keys=True), "note": note or ""}


# ---------------------------------------------------------------- the three things you call
def log_trial(disease, role, params, cv_f1, cv_f1_sd=None, cv_roc_auc=None,
              seed=config.RANDOM_STATE, note=""):
    """One tuning try (e.g. one Optuna trial): settings + CV score. No model file."""
    row = _base_row("trial", disease, role, params, seed, note)
    row.update(cv_f1=_r(cv_f1), cv_f1_sd=_r(cv_f1_sd), cv_roc_auc=_r(cv_roc_auc))
    _append(row)


def save_final(model, disease, role, params, cv_f1, cv_f1_sd=None, cv_roc_auc=None,
               test=None, seed=config.RANDOM_STATE, note="") -> Path:
    """Save a model fitted on the full training set under a never-reused name, then
    re-mark the best model for this disease and role. `test` = ensemble test metrics."""
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M")
    name = (f"layer2_{disease}_{role}_{ALGORITHM}_{config.DATASET_VERSIONS[disease]}"
            f"_f1-{cv_f1:.3f}_{stamp}")
    path = MODEL_DIR / f"{name}.joblib"
    k = 2
    while path.exists():                      # two saves in the same minute
        path = MODEL_DIR / f"{name}-{k}.joblib"
        k += 1
    joblib.dump(model, path, compress=3)
    test = test or {}
    row = _base_row("final", disease, role, params, seed, note)
    row.update(cv_f1=_r(cv_f1), cv_f1_sd=_r(cv_f1_sd), cv_roc_auc=_r(cv_roc_auc),
               test_f1=_r(test.get("f1")), test_roc_auc=_r(test.get("roc_auc")),
               test_pr_auc=_r(test.get("pr_auc")), name=path.stem,
               path=rel(path))
    _append(row)
    mark_best(disease, role)
    return path


def mark_best(disease, role):
    """Best = highest cross-validation F1 among the FINAL models of this disease and role."""
    rows = read()
    finals = [r for r in rows if r["kind"] == "final" and r["disease"] == disease
              and r["role"] == role and r["cv_f1"]]
    if not finals:
        return
    winner = max(finals, key=lambda r: float(r["cv_f1"]))
    for r in rows:
        if r["disease"] == disease and r["role"] == role and r["kind"] == "final":
            r["best"] = "yes" if r is winner else ""
    _write(rows)


def register_baselines():
    """Add today's API models (ml/models/layer2_*.joblib) once, with their saved test scores."""
    existing = {r["path"] for r in read() if r["kind"] == "baseline"}
    for disease in config.LAYER2:
        path = config.MODELS / f"layer2_{disease}.joblib"
        relpath = rel(path)
        if not path.exists() or relpath in existing:
            continue
        report = json.loads((config.REPORTS / f"layer2_{disease}.json").read_text())
        ens = report["results"]["stacked_ensemble"]
        row = _base_row("baseline", disease, "full", {}, config.RANDOM_STATE,
                        "model the API uses today; config.py settings")
        row.update(test_f1=_r(ens["f1"]), test_roc_auc=_r(ens["roc_auc"]),
                   test_pr_auc=_r(ens.get("pr_auc")), name=path.stem, path=relpath)
        _append(row)
        print(f"  registered baseline {relpath}")


# ---------------------------------------------------------------- command line
def _show(rows):
    cols = ["timestamp", "kind", "disease", "role", "cv_f1", "cv_roc_auc", "test_f1",
            "test_roc_auc", "best", "name"]
    print("  ".join(f"{c:>16s}" if c == "timestamp" else f"{c:>12s}" if c != "name" else c for c in cols))
    for r in rows:
        print("  ".join(f"{str(r[c])[:16]:>16s}" if c == "timestamp" else f"{str(r[c])[:12]:>12s}" if c != "name" else r[c] for c in cols))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("action", choices=["list", "best", "baselines"])
    ap.add_argument("--disease", choices=list(config.LAYER2))
    args = ap.parse_args()
    if args.action == "baselines":
        register_baselines()
        return
    rows = [r for r in read() if not args.disease or r["disease"] == args.disease]
    if args.action == "best":
        rows = [r for r in rows if r["best"] == "yes"]
    if not rows:
        print("  registry is empty" if not read() else "  no matching rows")
        return
    _show(rows)


if __name__ == "__main__":
    main()
