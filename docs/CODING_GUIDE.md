# Coding Guide: Dataset and AI Model

Step-by-step plan for the ML side of the FYP. Every step says **what** to run and **why**.
All commands run in PowerShell from the repo root `C:\fyp\FinalYearProjectUiTM`.

---

## 0. How the pieces fit

```
data/raw/                       (copied from your FYP\Dataset folder, never edited)
   │
ml/data.py        load + clean → X (features), y (target)
   │
ml/stacking.py    StackedEnsemble:  XGBoost ┐
                                    RF      ├─► out-of-fold probabilities ─► LightGBM meta-learner
                                    KNN*    ┘   (* StandardScaler on KNN only)
   │
ml/train.py       80:20 split → fit → evaluate on the untouched 20% → save
   │
ml/models/*.joblib  ─────────►  backend/app/main.py  (FastAPI)  ─────────►  Flutter app
ml/reports/*.json   (metrics for Chapter 4)
```

**You do NOT combine all datasets.** Two tiers, two different rules:

| Tier | Data | Rule |
|---|---|---|
| Layer 1 (Quick) | BRFSS 2015 | One file is enough. `diabetes_012_...csv` already holds all 3 targets, and it is row-identical to the heart-disease file (checked: 253,680 / 253,680 rows match on all 21 shared columns). |
| Layer 2 (Deep-Check) | heart, stroke, diabetes | Three separate models. Different columns, different patients — merging them would be meaningless. |

---

## 1. Every time you open a new terminal

```powershell
cd C:\fyp\FinalYearProjectUiTM
venv\Scripts\activate
```
**Why:** without activation, `python` is a different 3.12 install with none of your packages.
You'll see `(venv)` at the start of the prompt when it's active.

---

## 2. Confirm the pipeline still runs (2 minutes)

```powershell
python -m ml.tests.verify_architecture
python -m ml.train --layer2 all --sample 900
python -m ml.train --layer1 --sample 900
python -m backend.tests.test_api
```
The first command proves the code still matches Figure 3.8: SMOTE-Tomek runs only inside each
CV fold and never on the test set, the base learners are XGBoost + RF + KNN (scaler on KNN only)
feeding LightGBM, and Model 1 is one multi-output model. Expect `17/17 checks passed`.
**Why:** a full run takes much longer. If something is broken (a package update, an edited
config), you want to find out in 2 minutes, not 40. `--sample 900` trains on 900 rows and saves
`*_dev900` models, which the API test uses. Expect `All API checks passed.`

`python -m ml.train` (with `-m`) runs the file as part of the `ml` package, so `from ml import
config` works. Running `python ml/train.py` directly would fail on that import.

---

## 3. Full training — tomorrow

Start with Layer 2 (small, fast), then Layer 1 (big):

```powershell
python -m ml.train --layer2 all
python -m ml.train --layer1
```

**Why this order:** Layer 2 finishes in about a minute, so you see real results immediately and
catch problems early. Layer 1 is one multi-output model over 253,680 rows that learns all three
diseases one after another — roughly 10–20 min per disease, so up to about an hour, on your laptop
(estimate extrapolated from a 40k-row run that took 28 s; KNN and Tomek Links scale worse than
linearly). Layer 1 saves only when all three diseases are done, so let it finish.

You get **4 models in total**: 1 for Layer 1 (all three diseases) and 3 for Layer 2 (one per disease).

**Plug in your charger and keep the lid open.** Sleep mode pauses training.

Outputs:
- `ml/models/layer1_general.joblib` — Model 1 (one file, three diseases)
- `ml/models/layer2_heart.joblib`, `layer2_stroke.joblib`, `layer2_diabetes.joblib` — Model 2, one per disease
- `ml/reports/*.json` — every metric, confusion matrix, and the per-base-learner comparison
  (`layer1_general.json` has one results block per disease)

---

## 4. Read the results correctly

Each run prints a table like this:

```
model               accuracy  balanced  precision  recall   f1   roc_auc
stacked_ensemble    ...
xgboost             ...
random_forest       ...
knn                 ...
```

The bottom three rows are each base learner **alone** on the same test set. This table *is*
your evidence for the report's claim that stacking beats individual models — put it in Chapter 4.

**Judge by recall, F1, balanced accuracy and ROC-AUC — not accuracy.** On the dev runs you'll
already see the pattern: XGBoost and Random Forest alone score ~0.96 accuracy on stroke with
**recall ≈ 0** (they predict "no stroke" for everyone). The ensemble's accuracy is lower but it
actually finds stroke cases. That trade-off is exactly what §3.7.2 of your report argues for.

---

## 5. Then: EDA notebook (`ml/notebooks/01_eda_brfss.ipynb`)

Do this after the first full run, so you know what the model struggles with:
1. Class distribution per target (bar chart) — Chapter 3/4 figure
2. Feature distributions split by target (e.g. BMI by stroke yes/no)
3. Correlation heatmap — supports your §2.1 claim that the three diseases share risk factors

Load data the same way the pipeline does:
```python
import sys; sys.path.insert(0, "..")      # repo root, so `ml` is importable
from ml.data import load_brfss
X, Y = load_brfss()
```

---

## 6. Decisions to make after the first full run

These are recorded in CLAUDE.md under *Known issues*.

### 6a. "Risk %" is not a real probability yet
When SMOTE-Tomek is on, the meta-learner uses `class_weight="balanced"` to keep recall high.
That pushes probabilities upwards — the dev API test showed 79.8% stroke risk for a 52-year-old.
Fine for ranking, misleading as a percentage on screen. Options:
- **Calibrate** with `sklearn.calibration.CalibratedClassifierCV` on a held-out slice, so the
  number means "X out of 100 similar people". Most honest for a health app.
- Or keep it and label it "risk score" rather than "%" in the app.

### 6b. Prediabetes (Diabetes_012 = 1)
Only 1.8% of rows and survey answers barely separate it from diabetes/none. Expect low
macro-recall. Options: keep 3-class (matches the report) and discuss it, or merge 1 and 2 into
"diabetes risk" (binary) — most BRFSS papers do this. Your report says three-class, so changing
it means updating §3.4.1.

### 6c. Feature contract vs app forms
`ml/config.py` uses all 19 BRFSS features. The proposal's Quick Prediction form (Fig 3.18) lists
about 10. Either expand the form (all 19 are simple yes/no or 1–5 questions) or trim
`BRFSS_FEATURES` and retrain. Same check for each deep-check form against `LAYER2`.

### 6d. Heart dataset mismatch
The file you have is the 920-row UCI version (4 hospitals, missing values), not the 1,025-row
one in §3.4.2.1. The code handles it (`num > 0` → disease; `slope`, `ca`, `thal` dropped).
Update the report text to describe the dataset you actually used.

---

## 7. Hyperparameter tuning (later, optional)

All settings live in `ml/config.py` (`XGB_PARAMS`, `RF_PARAMS`, `KNN_PARAMS`, `META_PARAMS`,
`MINORITY_RATIO`). Change one value, re-run on `--sample 20000` to compare quickly, then do the
full run with the winner. Change **one thing at a time** so you know what caused the difference.

---

## 8. Things that will bite you

| Pitfall | What the code already does |
|---|---|
| Resampling before CV leaks synthetic copies of validation rows into training | SMOTE-Tomek runs inside each fold, on that fold's training part only |
| Resampling the test set inflates scores | Test set is split off first and never resampled |
| Unscaled KNN — BMI (12–98) drowns out the 0/1 features | StandardScaler on the KNN branch only |
| Duplicate rows in train *and* test (diabetes: 3,854) | Removed before splitting |
| App sends a value the model never saw → silently ignored | API uses fixed choices; `test_api.py` checks they match the trained categories |
| Committing models/data/keys | `.gitignore` covers `data/`, `*.joblib`, `*.pkl`, `ml/models/`, `serviceAccountKey.json` |

---

## 9. Commit your work

```powershell
git add .
git status            # check: no data/, no *.joblib, no venv/ in the list
git commit -m "Add ML pipeline, training CLI and FastAPI backend"
git push
```
**Why check `git status` first:** it's your last chance to spot a file that shouldn't go to GitHub.
