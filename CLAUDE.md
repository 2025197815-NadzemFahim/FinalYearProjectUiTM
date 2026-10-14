# FYP: Early Prediction of Chronic Diseases Using an AI-Based Mobile Application

Final-year capstone (CSP600), UiTM Shah Alam. I'm the sole developer.

## Architecture (matches the finalised proposal)
- Every model is a stacking ensemble: **XGBoost + Random Forest + KNN base learners → LightGBM meta-learner**
  - KNN is the only base learner wrapped with a StandardScaler (distance-based); trees need no scaling
  - Implemented as `ml.stacking.StackedEnsemble` (custom, not sklearn's StackingClassifier) so that
    SMOTE-Tomek runs *inside* each CV fold → out-of-fold predictions are leak-free
  - 80:20 stratified train/test split, 5-fold CV for out-of-fold meta-features
- Layer 1 (Quick Prediction): BRFSS 2015, 253,680 rows, 19 features, three targets:
  `Diabetes_012` (3-class), `HeartDiseaseorAttack`, `Stroke`. This is ONE model ("Model 1"):
  `MultiOutputClassifier(StackedEnsemble)` saved as `ml/models/layer1_general.joblib`. One
  `predict_proba` call returns a list of 3 probability arrays in `BRFSS_TARGETS` order. Internally it
  holds one ensemble per target (LightGBM has no multi-output, and SMOTE-Tomek rebalances one target at
  a time). The 80:20 split is stratified on the combination of all three labels.
- Total trained models: 4 = 1 (Layer 1) + 3 (Layer 2, one per disease)
  The diabetes_012 CSV already has all three targets; it is row-identical to the heart-disease CSV,
  so no merge is needed.
- Layer 2 (Deep-Check): heart (UCI, 920 rows), stroke (5,110), diabetes (100,000) — trained separately,
  never combined with each other or with BRFSS
- SMOTE-Tomek is conditional (on for BRFSS, stroke, diabetes; off for heart). Minority classes are raised
  to 30% of the majority (`MINORITY_RATIO`), not 1:1
- Backend: FastAPI loads saved models (joblib) and serves predictions; includes the clinical input
  conversion layer (FR-07) that maps real-world inputs to BRFSS codes
- Mobile: Flutter app with Firebase Auth + Firestore
- Database (Figure 3.14 ERD, see `docs/DATABASE.md`): Firestore `users/{uid}` (User) with subcollection
  `deepCheckResults/{resultID}` (DeepCheckResult); DiseaseInput + Heart/Stroke/DiabetesInput are an
  embedded `diseaseInput` map. App writes own profile + reads own history directly (security rules);
  only the backend (Admin SDK) writes results. Quick predictions are never stored.
  Developed on the local Firebase Emulator (project `demo-fyp-chronic`); no real project yet
- Feature lists in `ml/config.py` are the contract between models and app forms. Change one → retrain
  that model and update the matching app form and `backend/app/schemas.py`

## Repo layout
- `ml/config.py` paths, feature contracts, hyperparameters (single source of truth)
- `ml/data.py` loading/cleaning; `prepare_features` is shared with the backend
- `ml/stacking.py` the ensemble; `ml/evaluate.py` metrics; `ml/train.py` training CLI
- `ml/models/`, `ml/reports/` saved models and metrics JSON (gitignored)
- `backend/app/` FastAPI app (`main.py`, `schemas.py`, `conversion.py`, `db.py` = all Firestore access,
  `auth.py` = ID-token verification); `backend/db_tool.py` DB CLI; tests in `backend/tests/`
- `firebase/` emulator config, `firestore.rules`, `firestore.indexes.json`; local data in
  `firebase/emulator-data/` (gitignored)
- `mobile/` Flutter app (not created yet)
- `data/raw/brfss/`, `data/raw/layer2/` original datasets, never edit by hand (gitignored)
- `data/processed/` cleaned data written by notebooks (gitignored)
- `docs/CODING_GUIDE.md` step-by-step plan for the ML work; `docs/DATABASE.md` database guide

## Commands (repo root, venv active)
- Train: `python -m ml.train --layer1` and `python -m ml.train --layer2 all`
- Quick dev run: add `--sample 900` (saves `*_dev900` models, used by the API test)
- API: `uvicorn backend.app.main:app --reload`, docs at http://127.0.0.1:8000/docs
- API test: `python -m backend.tests.test_api`
- Emulators: `cd firebase` → `firebase emulators:start --import ./emulator-data --export-on-exit`
  (UI http://127.0.0.1:4000). If Firestore dies with "Unable to establish loopback connection", set
  `$env:JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=C:/fyp/tmp"` first
- Backend on emulators: set `$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"` and
  `$env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"` before `uvicorn`; without them the DB is disabled
  and deep checks are just not saved
- DB tool: `python -m backend.db_tool seed|users|history <email>|token <email>|reset`
- DB tests (emulators running): `python -m backend.tests.test_db` (20 checks: rules + API + DB)
- Architecture check: `python -m ml.tests.verify_architecture` (~1 min, 17 checks). Proves the code
  matches Figure 3.8 (in-fold SMOTE-Tomek, never on test, XGB+RF+KNN→LightGBM, Model 1 = one model).
  Rerun after any change to `ml/stacking.py`, `ml/train.py` or `ml/config.py`

## Environment (ALREADY SET UP, do not reinstall)
- OS: Windows 11, PowerShell. Repo at `C:\fyp\FinalYearProjectUiTM`
- Python 3.12.10 in `venv/` at repo root. Activate with `venv\Scripts\activate`
  (PowerShell execution policy already set to RemoteSigned for current user)
- Installed: pandas 3.x, numpy, scikit-learn, xgboost, lightgbm, imbalanced-learn,
  matplotlib, seaborn, jupyter, joblib, shap, fastapi, uvicorn, pydantic, firebase-admin
- `requirements.txt` is committed. Re-run `pip freeze > requirements.txt` after adding packages
- VS Code interpreter and notebook kernel point at the venv
- Flutter 3.47.x stable installed, `flutter doctor` fully green
- Android SDK is in the shared folder `C:\Android\Sdk` (Android Studio lives under a
  different Windows user, so Flutter is configured with `flutter config --android-sdk C:\Android\Sdk`)
- firebase-tools and flutterfire_cli installed, `firebase login` done
- Git identity configured, remote is on GitHub (private)

## Not done yet
- Full training run (only `--sample 900` dev models exist so far)
- `mobile/` not created (`flutter create mobile` comes later), so `flutterfire configure` not run
- Firebase project not created in the console (database runs on the emulator; go-live steps in
  `docs/DATABASE.md` §7)
- ERD / data dictionary (Fig 3.14, Tables 3.18-3.23) don't match the stored input fields; see
  `docs/DATABASE.md` §8
- No Android phone or emulator connected yet

## Conventions
- pandas 3.x: use `df.loc[mask, "col"] = value`, never chained assignment. Avoid `inplace=True`
- Cleaning is done in code (notebook or script) that reads `data/raw/` and writes
  `data/processed/`. Never modify raw files
- Never commit `serviceAccountKey.json`, datasets, or model files over 100 MB
- Keep notebooks numbered: `01_eda_brfss.ipynb`, `02_preprocessing.ipynb`, and so on

## Known issues / decisions pending
- Heart dataset on disk is the 920-row UCI version (target `num` 0-4 → binarised to num > 0),
  not the 1,025-row version described in the proposal §3.4.2.1. `slope`, `ca`, `thal` dropped
  (34/66/53% missing). The proposal text needs updating to match
- The meta-learner uses `class_weight="balanced"` when SMOTE-Tomek is on (recall priority), so
  `predict_proba` output is NOT a calibrated real-world probability. Decide whether to calibrate
  before showing "risk %" in the app
- Diabetes_012 class 1 (prediabetes) is 1.8% of rows and hard to separate; macro scores will be low
- App forms in the proposal (Fig 3.18, data dictionary) collect fewer fields than `ml/config.py`
  feature lists; forms must match the contract

## Current status
Week 2. Environment done, datasets in `data/raw/`, full ML pipeline + backend written and
smoke-tested on `--sample 900`. Next: full training run, then EDA notebook `01_eda_brfss.ipynb`.

## Preferences
- Reply in English only
- I'm strong in backend, architecture, AI and databases, weaker in frontend/UI, so explain Flutter UI choices more
- I'm new to the tooling here, so give step-by-step instructions and explain the reason for each command