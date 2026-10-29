# Improvement Plan: Layer 2 data and models, richer UI, fewer inputs

Created 2026-10-27. Status: **waiting at CHECKPOINT 1** (dataset search checklist below).

## Goals
1. Make the Layer 2 ensemble clearly better than any single model *(see objection O1: we measure this
   honestly; we can't promise it)*.
2. Make the UI richer than "enter readings, get a prediction" (tutorials + lifestyle quick check).
3. Reduce the readings typed into Quick Prediction and Deep-Check (profile + lifestyle pre-fill).

## Ground rules
- ML work is **Layer 2 only**. Layer 1, the existing models (`ml/models/*.joblib`), the existing datasets
  (`data/raw/`) and the API contract stay untouched. Every new artifact gets a **new name** (new files,
  new dataset versions, new endpoints such as `/v2/...` if ever needed).
- Repetitive per-disease work runs from **one script + a per-disease config** (like `config.LAYER2`).
- You plan and decide; I explain each concept with your data first. For your tasks I give hints and review.
  For my tasks I explain the key parts after writing them.
- **CHECKPOINT** = I stop and wait for your approval.

## Task table

Hours are rough estimates for working time, not compute time. Priority: **P1** = must do, **P2** = should do, **P3** = nice to have.

| # | Task | Owner | Order | Est. h | Depends on | Priority |
|---|---|---|---|---|---|---|
| A1 | This plan + objections | Claude | 1 | 0.5 | - | P1 |
| D1 | Dataset search checklist + clinically relevant readings per disease (below) | Claude | 2 | 1 | A1 | P1 |
| **CP1** | **CHECKPOINT 1: you approve the checklist and the reading lists** | You | 3 | - | D1 | - |
| D2 | Find and download candidate datasets; record URL, license, date for each | You | 4 | 6-10 | CP1 | P1 |
| D3 | Profile every candidate (rows, positives, features, units, label definition, missingness, overlap with current data, provenance); recommend a main dataset per disease | Claude | 5 | 3 | D2 | P1 |
| **CP2** | **CHECKPOINT 2: you choose the main dataset per disease** | You | 6 | 1 | D3 | - |
| D4 | Per-disease config + harmonise/clean/merge script (units, encodings, label check, cross-source duplicate removal, license log) | Claude | 7 | 6 | CP2 | P1 |
| D5 | Fill missing core features in secondary rows (conditioned on the row, never on the label), with real-vs-filled distribution comparison and source/flag columns | Claude | 8 | 6 | D4, decision O2 | P2 |
| **CP3** | **CHECKPOINT 3: you review the filled-vs-real comparison** | You | 9 | 1 | D5 | - |
| D6 | Versioned dataset (`data/processed/layer2_<disease>_v1.parquet`) + data card | Claude | 10 | 2 | D4 (D5) | P1 |
| M1 | Model registry + save utility (your naming scheme, registry file, "best" marker) | Claude | 11 | 3 | - | P1 ✅ done 2026-10-28: `ml/registry.py`, `ml/experiment.py`, `ml/model_registry.csv` |
| H1 | **Reduced heart model** `layer2_heart_reduced` (7 readings without a stress test: age, sex, cp, trestbps, chol, fbs, restecg), new name, same pipeline; compare full vs reduced on the same test set + repeated CV (shows what the stress test adds) | Claude builds config/script, you run training | 11b | 3-4 | M1 | P1 |
| M2 | Comparison script: (a) single models, (b) ensemble on main only, (c) ensemble on augmented, all on the SAME real-only test set, using repeated CV + the corrected t-test | Claude builds, you run | 12 | 4 | D6, M1 | P1 |
| M3 | Hyperparameter tuning of the whole ensemble (CV on training set only) | You (Claude hints/reviews) | 13 | 10-15 | M2 | P2 |
| **CP4** | **CHECKPOINT 4: results review; no backend switch without approval** | You | 14 | 1 | M3 | - |
| I1 | `docs/input_readings.md`: every reading per layer/disease, unit, range, how obtained, shared? | Claude | 15 | 3 | final feature sets | P1 ✅ done 2026-10-28; CP5 approved 2026-10-29 |
| **CP5** | **CHECKPOINT 5: approve inventory before any UI work** | You | 16 | - | I1 | - |
| U0 | Connect the app to the real API (replaces dummy predictions; prerequisite for pre-fill to mean anything) | Claude structure, you finish | 17 | 4 | CP5 | P1 |
| U1 | Lifestyle quick-check: proposed questions, levels, exact model encodings, unmappable answers | Claude proposes, you set thresholds | 18 | 2 | CP5 | P1 ✅ proposal in `docs/lifestyle_check_proposal.md`; CP6 approved 2026-10-29 (income table pending) |
| **CP6** | **CHECKPOINT 6: approve readings, levels, mappings** | You | 19 | - | U1 | - |
| U2 | Profile fields at sign-up + save to Firestore (age/DOB, sex, height, stable answers) | You (Claude structure) | 20 | 6 | CP6 | P1 |
| U3 | Lifestyle quick-check screens (retakeable) | Claude structure, you finish | 21 | 4 + 4 | CP6 | P1 |
| U4 | Pre-fill and collapse matching fields in Quick Prediction / Deep-Check | Claude structure, you finish | 22 | 4 + 3 | U2, U3 | P1 |
| U4b | Heart Deep-Check toggle "I haven't done a stress test": hides the 3 stress-test fields and uses the reduced model, with a "less precise" note | Claude structure, you finish | 22b | 2 + 1 | H1, U0 | P1 |
| U5 | Tutorial section (data-driven JSON, title/steps/tips/video placeholder, help icons, loading/error/offline states) | Claude structure, you add content/videos | 23 | 5 + 4 | I1 | P2 |
| T1 | Update thesis Ch 3 (datasets, features, UI) and Ch 4 (results) to match | You | 24 | 8+ | all | P1 |

Total: roughly **95-115 hours** of work. Before the January 2027 thesis deadline, that is tight alongside writing Chapters 4-5.

## What to drop first if time runs short
1. **D5 + comparison (c)** (filling missing features / augmented dataset). Highest risk, smallest
   guaranteed payoff (see O1, O2). Without it you still have (a) vs (b) on better-chosen data.
2. **M3 breadth.** Tune a small grid of the 3-4 parameters that matter most instead of every parameter.
3. **U5 videos.** Keep text tutorials and help icons; add videos later through the JSON file.

Never drop U0-U4. They fix a real, examinable flaw (the Quick form has 10 inputs but the model needs 19).

## Objections and decisions needed (you decide; nothing here is applied yet)

**O1. More data will not by itself make the ensemble beat single models.**
Your own results show this. Layer 2 diabetes has 96,000 rows and Layer 1 has 253,000 rows, and the
ensemble still only *ties* XGBoost there. Extra data improves every model, the single ones included.
Stacking gains come from base learners that make *different* mistakes, not from row count. More data is
still worth it for **stroke** (only 249 positive cases) and for **tighter confidence intervals**. But the
goal should be "measure honestly", not "make it win". Tuning until it wins on the test set would be
overfitting to the test set; examiners look for this.

**O2. "Synthetic readings" should be framed and built as *missing-value imputation*.**
- A value generated from the other readings in a row (never from the label) adds **no new information
  about the disease**. It is a smart guess of what the row already says. So it cannot teach the model
  anything the real columns didn't. Worse, the model can learn that this column is "uninformative" in
  secondary rows and weaken it for real patients. More rows with filled columns are not the same as more
  real evidence.
- The standard, examiner-safe method is **multiple imputation (MICE / IterativeImputer)**, fitted on
  the training rows only, with a missing-indicator flag. That is exactly what you described, but under a
  recognised name with a citable method. XGBoost and LightGBM can also take missing values directly with
  no filling at all. Comparison (c) will show which is better.
- **Decision:** keep D5 as "imputation (MICE) + missing flags", and treat (c) as an experiment that
  may lose. Agree?

**O3. Watch for duplicates disguised as new heart datasets.**
Many public heart datasets are re-uploads of the same UCI patients:
- Statlog Heart (270 rows) is a Cleveland subset.
- The Kaggle "heart.csv" with 1,025 rows is Cleveland duplicated.
- "Heart Failure Prediction" (918 rows) combines the same UCI sites.

Merging them with your current 920 rows would put **the same patients in train and test** and inflate
every score. D4 removes cross-source duplicates, but it is better not to collect them.

**O4. 10-20k rows of *clinical* heart readings (ECG, ST depression) probably don't exist publicly.**
Large heart datasets use **simpler readings**. For example, Kaggle's "Cardiovascular Disease dataset"
(~70,000 rows) has age, sex, height, weight, systolic/diastolic BP, cholesterol level, glucose level,
smoking, alcohol and activity.

That is also a **UI win**: a normal user can get BP at home, but cannot get ST depression or an ECG
result. Choosing such a set as the heart main dataset would serve Goal 1 (rows) and Goal 3 (inputs a
user can actually provide) together. The cost: it changes the heart deep-check readings (new endpoint
and Chapter 3 update), and its label quality must be checked in D3.

**O5. Diabetes already exceeds the row target (~100,000 rows).** I suggest you skip searching for diabetes
data and spend that time on stroke, which needs it most.

**O6. Tuning cost.** Each ensemble fit already does 5 internal folds. Tuning with 5-fold CV means 25 base
fits per trial. That is about 2 minutes per trial for heart/stroke and **5+ minutes** for diabetes, so set
a trial budget (e.g. 40-60 trials) and use Optuna or random search, not a full grid.

---

## CHECKPOINT 1: before you search

### Checklist for every candidate dataset
Record each one in a table: name, URL, license, download date.

1. **Same target.** What exactly counts as "has the disease"? For example: angiography-confirmed narrowing,
   a doctor's diagnosis, self-report, or "history of stroke". Different label definitions **cannot be merged**.
2. **Positive case count, not only total rows.** 20,000 rows with 300 positives helps less than
   5,000 rows with 1,000 positives.
3. **Core features present** (see the lists below). Secondary datasets need at least 70% of the main
   dataset's core features.
4. **Units and encodings documented**, e.g. cholesterol in mg/dL or mmol/L, age in years or days,
   sex coding. There must be a data dictionary.
5. **Provenance: real or synthetic?** Read the description. Many Kaggle health datasets are generated or
   are re-uploads (see O3). Prefer UCI, PhysioNet, government surveys, or papers that describe collection.
6. **Population.** Country, years, clinical patients or general public. Note it for the limitations
   section; Malaysian data is a bonus.
7. **License.** CC0, CC BY, ODbL and public-domain government data are fine. "Unknown" or "Other" means
   use with caution and cite the source; avoid it if there is an alternative.
8. **Missingness.** Under ~30% missing per core feature is workable.
9. **Overlap check.** Is it the same patients as data you already have? (row count, column names, same
   value patterns)

### Clinically relevant readings per disease
These come from established risk-factor sets (Framingham/SCORE for heart, the major stroke risk factors,
FINDRISC/ADA for diabetes). **In bold:** a normal user can provide it (self-report or home measurement).

**Heart disease**
- **age, sex, height, weight (BMI), systolic BP, diastolic BP, smoking, diabetes status, physical activity**
- total cholesterol (or LDL/HDL), fasting glucose: lab, but many people know their latest value
- clinical only (current UCI set): chest pain type, resting ECG, max heart rate, exercise angina,
  ST depression

**Stroke**
- **age, sex, hypertension (or systolic BP), heart disease history, diabetes status, smoking, BMI**
- **atrial fibrillation (AF)**: one of the strongest stroke risk factors, and missing from your current
  dataset. Worth searching for.
- average glucose: lab

**Diabetes** *(no search needed, see O5)*
- **age, sex, BMI, waist circumference, family history, physical activity, hypertension, smoking**
- HbA1c, fasting/random glucose: lab

Reply with your approval or changes to the checklist and the reading lists, and your answers to
O1-O5. Then you start D2.

---

## D3 (early): profile of the first downloads, 2026-10-27

Folder: `Downloads/new dataset/`. Checks: rows, positives, duplicates, identical-file hash vs `data/raw/`,
patient overlap with the current UCI 920 (matched on age, sex, BP, cholesterol, max HR, ST depression),
and learnability (5-fold ROC-AUC of a plain Random Forest; 0.5 = no signal).

| File | Rows (unique) | Target (positives) | Finding | Verdict |
|---|---|---|---|---|
| DIABETES/diabetes_prediction_dataset.csv | 100,000 (96,146) | diabetes (8,500) | **Identical file** to the current dataset | nothing new |
| STROKE/stroke.csv | 5,110 | stroke (249) | **Identical file** to the current dataset | nothing new |
| heart_disease_uci.csv | 920 | num>0 (509) | **Identical file** to the current dataset | nothing new |
| heart.csv, heart (1).csv (same file) | 1,025 (302) | target (526) | 723 duplicate rows; the 302 unique = **100% your Cleveland patients**; label **flipped** (0% agreement with UCI) | reject |
| heart 23.csv | 303 (302) | target (165) | **100% your Cleveland patients**, label **flipped** | reject |
| data (1).csv | 294 (293) | num | Hungarian site, **92% already in UCI** (rest have missing keys), labels agree | reject (no new patients) |
| cleaned_merged_heart_dataset.csv | 1,888 (602) | target (977) | 1,286 duplicates; **96% already in UCI**; labels agree only 47% (mixes flipped and unflipped copies) | reject (would corrupt labels) |
| heart_attack_prediction_dataset.csv | 8,763 | Heart Attack Risk (3,139) | **AUC 0.509 = no signal**; consistent with a randomly generated dataset | reject |
| Medicaldataset.csv | 1,319 | heart attack at hospital (810) | AUC 0.997 only because of troponin/CK-MB (the blood tests that *diagnose* a heart attack); 0.59 without them; heart rate up to 1,111 (data errors); different target | reject for this app |
| heart_failure_clinical_records_dataset.csv | 299 | death during follow-up (96) | Patients who already have heart failure; target = mortality | reject (different target) |
| **framingham.csv** | **4,238** | **TenYearCHD: heart disease within 10 years (644)** | Real cohort study; **future risk = true "early prediction"**; readings mostly user-providable (age, sex, smoking, cigs/day, BP meds, hypertension, diabetes, total cholesterol, systolic/diastolic BP, BMI, heart rate, glucose); AUC 0.706 (typical for this data); ≤9% missing | **candidate main dataset** (different features from UCI, so not mergeable with it) |

Also noted: the current diabetes file has **3,854 exact-duplicate rows**, which can fall on both sides of
the train/test split. Record it in the data card and limitations; it is not changed (scope rule).

## Decisions log
- 2026-10-28: **Stroke** keeps the current dataset (5,110 rows, 249 positives); limitation documented.
  **Diabetes** keeps the current dataset (O5 accepted). **Framingham rejected** for heart: its target is
  10-year future risk; the app should detect current disease. Heart main dataset still open: you will
  download the ~70k Cardiovascular Disease dataset for profiling (D3).
- 2026-10-28: **Heart keeps UCI** as the main dataset (gold-standard angiography label; "deep" clinical
  readings). Added **H1 reduced heart model** + **U4b toggle** for users without a stress test. The
  70k Cardiovascular dataset is not pursued.
- Where each Layer 2 reading comes from (feeds I1): only the heart stress-test readings (thalch, exang,
  oldpeak) are hospital-only. Diabetes HbA1c and glucose and stroke glucose are routine clinic or
  home-meter tests. Everything else is self-report or a home measurement.
