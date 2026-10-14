# Database Guide (Firebase Auth + Firestore)

Implements the ERD in Figure 3.14. Everything runs **locally on the Firebase Emulator** —
no Firebase project, no internet, no cost, and you can wipe and reseed it freely.
Moving to a real Firebase project later is covered in §7.

All commands: PowerShell, from the repo root `C:\fyp\FinalYearProjectUiTM`.

---

## 1. What was built

| Piece | File | Job |
|---|---|---|
| Emulator config | `firebase/firebase.json`, `.firebaserc` | Auth on :9099, Firestore on :8080, web UI on :4000, demo project `demo-fyp-chronic` |
| Security rules | `firebase/firestore.rules` | Who may read/write what (enforced for the Flutter app) |
| Index | `firebase/firestore.indexes.json` | History filtered by disease, newest first |
| Data-access layer | `backend/app/db.py` | The **only** place the backend touches Firestore |
| Token checking | `backend/app/auth.py` | Verifies the app's Firebase ID token → user's uid |
| API changes | `backend/app/main.py` | Deep checks save to history when signed in; `GET /history`, `GET /history/{id}` |
| DB tool | `backend/db_tool.py` | Seed demo data, list users/history, get a login token, reset |
| Tests | `backend/tests/test_db.py` | 20 checks: security rules + API + database |

---

## 2. Start the database (every session)

**Terminal 1 — emulators** (leave it running):
```powershell
cd C:\fyp\FinalYearProjectUiTM\firebase
firebase emulators:start --import ./emulator-data --export-on-exit
```
Wait for **"All emulators ready!"**.

- `--import ./emulator-data` loads the data saved last time.
- `--export-on-exit` saves everything when you stop it — **stop with Ctrl+C**, not by closing
  the window, or your changes since the last start are lost.
- The data lives in `firebase/emulator-data/` (gitignored).

**Terminal 2 — first time only, add demo data:**
```powershell
cd C:\fyp\FinalYearProjectUiTM
venv\Scripts\activate
python -m backend.db_tool seed
```
Creates `ali@demo.com` and `siti@demo.com` (password `password123`) with profiles and sample history.

---

## 3. Three ways to access the data

### A. Emulator UI (browser) — easiest
Open **http://127.0.0.1:4000**
- **Firestore** tab → browse `users` → click a user → `deepCheckResults`. You can add, edit and
  delete documents by hand. Good for seeing the structure and for screenshots in your report.
- **Authentication** tab → the registered accounts (email, uid).

Edits here go through the Admin path, so they **bypass the security rules** — use the tests (§5)
to check rules.

### B. DB tool (terminal)
```powershell
python -m backend.db_tool users                          # all profiles
python -m backend.db_tool history ali@demo.com           # one user's results, newest first
python -m backend.db_tool history ali@demo.com --disease heart
python -m backend.db_tool token ali@demo.com             # login token (for C)
python -m backend.db_tool reset                          # wipe everything (emulator only)
```
`reset` refuses to run unless you're on the emulator, so it can never wipe a real project.

### C. Through the API, like the app would
**Terminal 2** — run the backend connected to the emulators:
```powershell
$env:FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"
$env:FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099"
uvicorn backend.app.main:app --reload
```
The two `$env:` lines tell the backend to use the emulators. They only last for that terminal
window. Startup should print `Database: connected to emulator...`.

**Terminal 3** — get a token:
```powershell
venv\Scripts\activate
python -m backend.db_tool token ali@demo.com
```
Copy the long `eyJ...` string.

Then open **http://127.0.0.1:8000/docs**:
1. Click **Authorize 🔒** (top right) → paste the token → Authorize.
2. Try `POST /predict/deep/heart` → the response has a `result_id` → it was saved.
3. Try `GET /history` → your saved results.
4. Refresh the Emulator UI → the new document is there.

Without a token, deep checks still work but aren't saved (`result_id: null`) — that's the
anonymous/guest path. Tokens expire after 1 hour; get a new one if you see `401`.

---

## 4. How the ERD maps to Firestore

Firestore is a **document** database (collections of documents), not tables with joins,
so the ERD is translated like this:

```
users/{userID}                                   ← User
   userName, userEmail, userAge, userSex, userCreate_at
   └── deepCheckResults/{resultID}               ← DeepCheckResult (subcollection)
          resultID, userID, diseaseType, risk_percentage,
          explanation_text, created_at, modelName
          diseaseInput: { inputID, ...fields }   ← DiseaseInput + Heart/Stroke/DiabetesInput
```

| ERD | Firestore | Why |
|---|---|---|
| User (PK userID) | `users/{userID}` — document id = Firebase Auth uid | The login account and the profile share one id, so no separate key is needed |
| User **1 — 0..*** DeepCheckResult | `deepCheckResults` as a **subcollection** under the user | The relationship is the path itself: a user's results live inside their document. Fetching a user's history needs no join, and the security rules can say "only your own" simply |
| DeepCheckResult **1 — 1** DiseaseInput | `diseaseInput` **embedded map** inside the result | Always created and read together; embedding avoids a second read. Standard Firestore modelling for one-to-one |
| DiseaseInput → Heart/Stroke/DiabetesInput (specialisation) | the map's fields depend on `diseaseType` | A document database allows different fields per document, so the three subtypes don't need three tables |
| FK userID | stored as a field *and* implied by the path | Kept as a field so a result is self-describing when read on its own |

**Not stored on purpose:** Quick Prediction results (report §3.5.1 — only deep checks are kept).

**Added beyond the ERD:** `modelName` — which trained model produced the risk. If you retrain,
you can still tell which results came from which model version.

---

## 5. Security rules and tests

What the rules (`firebase/firestore.rules`) enforce for the Flutter app:

| Who | Can | Cannot |
|---|---|---|
| Signed-in user | read/create/update **their own** profile | read anyone else's; delete profiles |
| | read **their own** history | write any result — only the backend can, so nobody can fake a risk % |
| Profile writes | must have age 18–120, sex male/female, a non-empty name, and the email of the signed-in account; `userCreate_at` must be the server time | change their email or creation time later |
| Not signed in | nothing | everything |

The backend uses the Admin SDK, which bypasses the rules — that's how it saves results.

**Run the tests** (emulators must be running):
```powershell
python -m backend.tests.test_db
```
Expect `20/20 checks passed`. These talk to Firestore exactly like the app does (REST + the
user's token), so they genuinely test the rules — the Emulator UI doesn't.

**After editing `firestore.rules`:** the emulator reloads the file automatically. Rerun the tests.

---

## 6. Troubleshooting

**`Firestore Emulator has exited with code: 1` and `firestore-debug.log` says
"Unable to establish loopback connection"** — a Java-on-Windows socket issue. Fix (same terminal):
```powershell
New-Item -ItemType Directory -Force C:\fyp\tmp
$env:JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=C:/fyp/tmp"
firebase emulators:start --import ./emulator-data --export-on-exit
```

**Port already in use (8080 / 9099 / 4000)** — an old emulator is still running. Close it, or
find it with `netstat -ano | findstr :8080` and end that PID in Task Manager.

**`Database: disabled` when starting the backend** — the `$env:` lines weren't set in *that*
terminal (§3C).

**`401 Invalid or expired token`** — tokens last 1 hour. Run `db_tool token` again.

**`Sign-in failed: EMAIL_NOT_FOUND`** — run `python -m backend.db_tool seed` first.

---

## 7. Moving to a real Firebase project (later)

1. Firebase console → create the project → enable **Authentication → Email/Password** and
   **Firestore**.
2. Project settings → Service accounts → **Generate new private key** → save as
   `serviceAccountKey.json` **outside the repo or in it — it's gitignored either way. Never commit it.**
3. Deploy rules and indexes: `cd firebase` → `firebase use --add` (pick your project) →
   `firebase deploy --only firestore`
4. Run the backend with the real project instead of the emulator:
   ```powershell
   $env:FIREBASE_CREDENTIALS = "C:\path\to\serviceAccountKey.json"
   $env:FIREBASE_PROJECT_ID = "your-project-id"
   uvicorn backend.app.main:app --reload
   ```
   (Don't set the `*_EMULATOR_HOST` variables.)
5. Flutter: `flutterfire configure` in `mobile/`.

---

## 8. Improvements for you to work on

Pick any — each is self-contained. Rerun `python -m backend.tests.test_db` after each one.

### Make the ERD/report match what's stored (report accuracy)
The data dictionary (Tables 3.18–3.23) was written before the models were finalised.
The database stores **exactly what the model receives** (`backend/app/schemas.py`), so the
input fields differ:

| ERD entity | ERD fields | Actually stored | Difference |
|---|---|---|---|
| HeartDiseaseInput | resting_bp, cholesterol, fasting_blood_sugar, max_heart_rate, st_depression, **major_vessel_number**, chest_pain_type, **high_bp** | age, sex, chest_pain_type, resting_bp, cholesterol, fasting_blood_sugar_over_120, **resting_ecg**, max_heart_rate, **exercise_induced_angina**, st_depression | `major_vessel_number` dropped (66% missing in the dataset); `high_bp` isn't a model input; age, sex, resting ECG, exercise angina added |
| StrokeInput | glucose_level, bmi, smoking_history (**Boolean**), hypertension (**String**) | age, sex, hypertension, heart_disease, ever_married, work_type, residence_type, avg_glucose_level, bmi, smoking_status | Types swapped in the dictionary (hypertension is yes/no; smoking is a category); 6 model inputs missing |
| DiabetesInput | hba1c_level, glucose_level, bmi, hypertension, smoking_history | age, sex, hypertension, heart_disease, smoking_history, bmi, hba1c_level, blood_glucose_level | age, sex, heart_disease added |
| DeepCheckResult | explanation_text (String) | explanation_text (**list** of strings) | The API returns several notes |
| DeepCheckResult | — | modelName | Added for traceability |

→ Update Figure 3.14 and Tables 3.18–3.23. (Or change the schemas and retrain — but the
diagram should follow the code, not the other way round.)

### Database improvements
1. **Store date of birth instead of age.** `userAge` goes out of date every birthday. Store
   `userBirthDate` (timestamp), compute age when needed. Update `validProfile()` in the rules,
   `create_user_profile()` in `db.py`, the seed data, and the tests.
2. **Paginate history.** `list_deep_checks()` returns up to 50. Add a `start_after` cursor
   (Firestore's `start_after(snapshot)`) so the app can load more on scroll.
3. **Let users delete their own history.** Add `allow delete: if isOwner(userId);` under
   `deepCheckResults` in the rules, plus a test that user B *can't* delete user A's result.
4. **Account deletion (PDPA).** Health data is sensitive personal data under Malaysia's PDPA
   2010. Add `DELETE /me` that calls `db.delete_user_data()` and `auth.delete_user()`. Good
   point for your report's ethics/privacy section.
5. **Risk level field.** Add `riskLevel` = "low" / "moderate" / "high" from the percentage when
   saving, so the History screen can colour-code without recalculating.
6. **Profile photo.** The Profile interface (Figure 3.23) shows a photo — add
   `userPhotoURL` and store images in Firebase Storage (needs the Storage emulator too).
7. **Rules unit tests in JavaScript.** Firebase's official `@firebase/rules-unit-testing`
   library tests rules in isolation — a more standard alternative to the REST tests here.
