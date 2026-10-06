# FYP: Early Prediction of Chronic Diseases Using an AI-Based Mobile Application

Final-year capstone (CSP600), UiTM Shah Alam. I'm the sole developer.

## Architecture
- Layer 1: stacking ensemble (XGBoost + Random Forest base learners, LightGBM meta-learner) wrapped in MultiOutputClassifier, trained on BRFSS 2015 (253,680 rows, 3-class diabetes health indicators)
- Layer 2: disease-specific models trained on separate datasets
- Class imbalance handled with SMOTE-Tomek
- Backend: FastAPI loads saved models (joblib) and serves predictions
- Mobile: Flutter app with Firebase Auth + Firestore

## Repo layout
- `ml/` notebooks, training scripts, saved models
- `backend/` FastAPI app
- `mobile/` Flutter app (not created yet)
- `data/raw/` original datasets, never edit by hand (gitignored)
- `data/processed/` cleaned data written by notebooks (gitignored)

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
- BRFSS and Layer 2 datasets not yet downloaded into `data/raw/`
- `mobile/` not created (`flutter create mobile` comes later), so `flutterfire configure` not run
- Firebase project not created in the console
- No Android phone or emulator connected yet

## Conventions
- pandas 3.x: use `df.loc[mask, "col"] = value`, never chained assignment. Avoid `inplace=True`
- Cleaning is done in code (notebook or script) that reads `data/raw/` and writes
  `data/processed/`. Never modify raw files
- Never commit `serviceAccountKey.json`, datasets, or model files over 100 MB
- Keep notebooks numbered: `01_eda_brfss.ipynb`, `02_preprocessing.ipynb`, and so on

## Current status
Week 2 of the semester. Environment setup is complete. Next task: download BRFSS
into `data/raw/` and start EDA (class distribution first).

## Preferences
- Reply in English only
- I'm strong in backend, architecture, AI and databases, weaker in frontend/UI, so explain Flutter UI choices more
- I'm new to the tooling here, so give step-by-step instructions and explain the reason for each command