# Demo Guide: progress presentation

Shows the three parts: **AI model**, **Firebase** (database + login) and **UI** (Flutter app).
Start everything **15 minutes before** the presentation, in this order. You need 3 PowerShell windows.

> **The app now uses the real AI** (Window 2 must be running). Two things are still kept only in
> the app's memory until Firestore saving is done (task U2): your saved details and History.
> So, for the app part, **create a new account in the app first** (step 4): the seeded demo
> accounts have no date of birth/sex in the app yet and would show "Account details missing".

---

## Window 1: Firebase emulators (database + login, running locally)
```powershell
cd C:\fyp\FinalYearProjectUiTM\firebase
$env:JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=C:/fyp/tmp"
firebase emulators:start --import ./emulator-data --export-on-exit
```
Wait for "All emulators ready". Open **http://127.0.0.1:4000** (Emulator UI).

## Window 2: the API (loads the AI models)
```powershell
cd C:\fyp\FinalYearProjectUiTM
venv\Scripts\activate
$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
$env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
uvicorn backend.app.main:app --reload
```
Wait for "Loaded models: [...]" (Model 1 is 600 MB, so this takes about a minute). Then open
**http://127.0.0.1:8000/docs**.

## Window 3: the app
```powershell
cd C:\fyp\FinalYearProjectUiTM\mobile
flutter run -d chrome
```
The seeded demo accounts (`backend/db_tool.py`) are for steps 2-3 (the API page). For the app,
create an account in step 4.

---

## The presentation, in story order (about 10 minutes)

### 1. The design (1 min)
Show your architecture diagram (Figure 3.8):
- Quick Check = **one** multi-output model for 3 diseases (BRFSS).
- Deep-Check = **3 disease models**.
- Each model = XGBoost + Random Forest + KNN → LightGBM meta-learner (stacking).

### 2. The AI is real and correctly built (3 min)
**a) Live proof the design matches the diagram** (Window 2 must be stopped first, or open a 4th window
with the venv active). It takes about 1 minute and prints 17 PASS lines:
```powershell
python -m ml.tests.verify_architecture
```
Say: *"This automatically checks that SMOTE-Tomek only touches training data, the test set is never
resampled, and the stack has the three base learners and the LightGBM meta-learner."*

**b) Live predictions** at http://127.0.0.1:8000/docs → `POST /predict/quick` → **Try it out** → paste → **Execute**.

Healthy 28-year-old:
```json
{"age": 28, "sex": "female", "weight_kg": 55, "height_cm": 160, "high_blood_pressure": false,
 "high_cholesterol": false, "cholesterol_checked_last_5_years": true, "smoked_100_cigarettes": false,
 "physically_active_last_30_days": true, "eats_fruit_daily": true, "eats_vegetables_daily": true,
 "alcohol_drinks_per_week": 0, "has_health_coverage": true, "skipped_doctor_due_to_cost": false,
 "general_health": 1, "poor_mental_health_days": 0, "poor_physical_health_days": 0,
 "difficulty_walking": false, "education_level": 6, "income_level": 8}
```
At-risk 64-year-old:
```json
{"age": 64, "sex": "male", "weight_kg": 105, "height_cm": 170, "high_blood_pressure": true,
 "high_cholesterol": true, "cholesterol_checked_last_5_years": true, "smoked_100_cigarettes": true,
 "physically_active_last_30_days": false, "eats_fruit_daily": false, "eats_vegetables_daily": false,
 "alcohol_drinks_per_week": 0, "has_health_coverage": true, "skipped_doctor_due_to_cost": false,
 "general_health": 4, "poor_mental_health_days": 0, "poor_physical_health_days": 15,
 "difficulty_walking": true, "education_level": 3, "income_level": 3}
```
Say: *"Same model, different readings: about 0.1-0.2% for the healthy person and about 50-70% for the
at-risk person, sorted from highest to lowest risk."*

**c) The results** (have these open beforehand):
- `ml/reports/figures/layer1_HeartDiseaseorAttack_reliability.png` and
  `ml/reports/figures/layer2_heart_reliability.png`: *"When the model says 40%, about 40% really had
  the disease, so the percentage is honest."*
- The repeated cross-validation tables (see "Key numbers" below): *"Tested 25 times per dataset with a
  significance test. The ensemble matches the best single model and gives the best-calibrated
  percentages. It is not significantly better, and I report that honestly."*

### 3. Firebase: login + saving results (2 min)
**a) Get a login token** (new window, venv active):
```powershell
python -m backend.db_tool token ali@demo.com
```
**b)** On the /docs page click **Authorize** (top right) → paste the token → Authorize.
**c)** `POST /predict/deep/heart` → Try it out → paste → Execute:
```json
{
  "age": 58, 
  "sex": "male",
  "chest_pain_type": "asymptomatic",
  "resting_bp": 146,
  "cholesterol": 236,
  "fasting_blood_sugar_over_120": false,
  "resting_ecg": "normal",
  "max_heart_rate": 132, "exercise_induced_angina": true,
  "st_depression": 1.8
}
```
The response has a `result_id`, so it was saved.

**d)** In the Emulator UI (http://127.0.0.1:4000):
- **Authentication** tab: the demo users.
- **Firestore** tab: `users` → the user → `deepCheckResults` → the new result.

Say: *"Deep-check results are saved per user, and the security rules only let users read their own."*

### 4. The app (3 min)
Window 3 (Chrome). Press **F12** → phone icon to show it at phone size.
1. **Login**: show the wrong-password popup.
2. **Create Account** (date of birth, sex, contact are asked only here) → back to Login → log in
   with the new account. Show **Forgot Password** too (Firebase sends the reset).
3. **Main** → **Predict a Disease** → "Complete your details" → My details → Medical history →
   Lifestyle check (show the levels, e.g. "Semi-active") → Quick Prediction now asks only 5 things
   → **Check** → **real** percentages from the AI → **Deep Check** (heart asks about a stress test
   first) → result with the model's own notes. *"Every check reuses the saved details, so the
   Quick check asks 5 readings instead of 20."*
4. **History** (grouped by date) → the new result is at the top.
5. **Profile** → My details / Medical history / Lifestyle check → **Log out**.

Say: *"All 10 interfaces from Section 3.5.4 are built, plus the details screens, and the app is
connected to the AI: 32 automated tests."*

### 5. What's next (1 min)
From `docs/improvement_plan.md`:
- connect the app to the AI;
- lifestyle quick check + profile pre-fill (Quick Prediction drops from 20 inputs to 5);
- a reduced heart model for users without a stress test;
- tutorials on taking readings;
- hyperparameter tuning with a model registry.

---

## Key numbers to quote

| Model | Ensemble result | vs best single model |
|---|---|---|
| Quick Check: heart | ROC-AUC 0.844 | equal to XGBoost (0.844) |
| Quick Check: stroke | ROC-AUC 0.809 | equal to XGBoost (0.810) |
| Quick Check: diabetes | ROC-AUC 0.784 | slightly above XGBoost (0.779) |
| Deep-Check: heart (25-round CV) | ROC-AUC 0.873, best Brier 0.141 | equal to RF (0.872) |
| Deep-Check: stroke (25-round CV) | ROC-AUC 0.812, best Brier 0.044 | equal to XGBoost (0.809) |
| Deep-Check: diabetes | ROC-AUC 0.977 | equal to XGBoost (0.977) |

Calibration (ECE, 0 = perfect): Quick Check 0.001-0.003; Deep-Check diabetes 0.003, stroke 0.021,
heart 0.064 (184 test patients).

## If something goes wrong
| Problem | Fix |
|---|---|
| Firestore emulator crashes with "loopback connection" | Run the `$env:JAVA_TOOL_OPTIONS=...` line, then start again |
| `/docs` says "Model not trained yet" | Wrong folder: Window 2 must start in `C:\fyp\FinalYearProjectUiTM` |
| Deep check response has `result_id: null` | Not authorized (step 3b), or Window 2 started without the two `$env:` lines |
| App login spins forever | Window 1 (emulators) isn't running |
| Port already in use | Close the old window, or restart the PC |
