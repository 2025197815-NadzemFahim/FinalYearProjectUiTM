# Mobile App Guide (Flutter)

All 10 interfaces from report Section 3.5.4 are built, plus My details, Medical history and the
Lifestyle check. **Predictions come from the real AI** through the FastAPI backend; saved details
and History are still kept in memory (tasks U2 and 3 in `docs/improvement_plan.md`). **`docs/UI_GUIDE.md`** is the main guide to the screens: mockup → file mapping,
Flutter concepts and exercises. This file covers running the app and connecting the real backend.

All commands: PowerShell, inside `C:\fyp\FinalYearProjectUiTM\mobile`.

---

## 1. Run it

**Terminal 1 — Firebase emulators** (the app signs in against them; see `docs/DATABASE.md`):
```powershell
cd C:\fyp\FinalYearProjectUiTM\firebase
firebase emulators:start --import ./emulator-data --export-on-exit
```

**Terminal 2 — the API (the AI models):**
```powershell
cd C:\fyp\FinalYearProjectUiTM
venv\Scripts\activate
uvicorn backend.app.main:app --reload
```
Wait for "Loaded models: [...]" (about a minute). Without it, checks show *"Can't reach the
prediction server… Is the API running?"*. To try the screens without the API (sample numbers):
`flutter run -d chrome --dart-define=USE_DEMO_PREDICTIONS=true`.

**Terminal 3 — the app:**
```powershell
cd C:\fyp\FinalYearProjectUiTM\mobile
flutter run -d chrome
```
**Until profile saving uses Firestore (U2), create an account in the same app session first.**
Date of birth, sex and contact are asked only at Create Account and are kept in memory, so the
seeded demo accounts (and accounts made in an earlier run) show *"Account details missing"* when
starting a check. Create Account → log in with it → complete your details → check.

While it runs: press **r** for hot reload (instant UI changes, keeps you logged in),
**R** for hot restart, **q** to quit.

The red "Running in emulator mode" strip at the bottom is Firebase's own warning in web debug
builds. It disappears with a real Firebase project.

**On an Android emulator** (once you set one up in Android Studio): `flutter run` and pick it.
The app automatically uses `10.0.2.2` — the Android emulator's address for your PC.
**On a real phone over Wi-Fi:** `flutter run --dart-define=EMULATOR_HOST=<your PC's IP>`
(find it with `ipconfig`), start the emulators with `--host 0.0.0.0` in `firebase.json`, and the
API with `uvicorn backend.app.main:app --host 0.0.0.0`. The same address is used for both
(`config/api_config.dart`).

**Tests** (no emulator or API needed, ~10 s): `flutter test` → expect `All tests passed!` (37 tests).
**Lint:** `flutter analyze` → expect `No issues found!`

---

## 2. Structure

The full folder tree, with one line per file, is in `docs/UI_GUIDE.md` §3. In short:
`models/` (data), `screens/` + `widgets/` (what you see), `services/` (Firebase, AI, history),
`theme/` (colours and fonts), `navigation/` (tabs).

### The three rules this structure follows

**1. Screens never talk to Firebase. Services do.**
`LoginScreen` calls `auth.signIn(...)`; only `auth_service.dart` knows about Firebase.
Same idea as `backend/app/db.py` on the server. When you add Firestore (history, profile),
put it in `services/history_service.dart` / a new `services/profile_service.dart`. Don't put
`FirebaseFirestore.instance` inside a screen.

**2. Services are passed in, not created inside screens.**
Screens receive one `AppServices` bundle (`services.auth`, `services.predictions`,
`services.history`). That's why the tests can pass a `FakeAuthService` and run in seconds
without Firebase. Add new services to `AppServices` the same way.

**3. AuthGate decides login vs. app — screens don't navigate after sign-in/out.**
`signIn()` / `signOut()` change Firebase's state → `authStateChanges()` emits → `AuthGate`
rebuilds with the right screen. One place decides, so a signed-out user can never land on a
private screen. Firebase also remembers the session, so reopening the app skips the login.

---

## 3. Flutter concepts used (with where to look)

| Concept | What it is | Example |
|---|---|---|
| **StatelessWidget** | Draws from what it's given; can't change itself | `ProfileScreen`, `PrimaryButton` |
| **StatefulWidget + setState()** | Has data that changes while open; `setState` redraws | `LoginScreen` — password visibility, loading spinner |
| **Form + validator** | Groups fields; `validate()` shows all errors at once (FR-04) | `validateEmail` in `login_screen.dart` |
| **TextEditingController** | Holds a field's text; `dispose()` it when the screen closes | `_email`, `_password` |
| **StreamBuilder** | Rebuilds whenever a stream emits | `AuthGate` |
| **showDialog** | Popup; `await` it to get the button pressed | error popup, "Log out?" confirm |
| **Stack** | Layers widgets on top of each other | wave behind the login form |
| **CustomPainter** | Draws free-form shapes | `wave_header.dart` |
| **SafeArea** | Keeps content clear of the notch / status bar | every screen |
| **SingleChildScrollView** | Lets a page scroll when the keyboard covers it | login form |
| **ValueListenableBuilder** | Rebuilds when a `ValueNotifier` changes | `HomeShell` (tab), `HistoryScreen` (list) |
| **IndexedStack** | Keeps several pages alive, shows one | the 3 tabs in `HomeShell` |
| **`Key('...')`** | A name tests use to find a widget | `Key('login')` |

More concepts, explained for this project: `docs/UI_GUIDE.md` §7.

---

## 4. Connecting the real data

| Service | Now | Next |
|---|---|---|
| `ApiPredictionService` (`services/prediction_service.dart`) | ✅ **real AI**: `POST /predict/quick` and `/predict/deep/{disease}`; sends the login token so deep checks are saved; clear messages for every failure. Requests are built in `models/api_payloads.dart` | the "no stress test" heart check gets its endpoint after the reduced model (H1) is trained and approved; until then it shows a message |
| `ProfileService` | in memory, cleared when a different person logs in | **U2 (you):** read/write `users/{uid}` (layout in `docs/lifestyle_check_proposal.md` section D) |
| `HistoryService` | in memory (7 samples + this session's checks), cleared when a different person logs in | read `users/{uid}/deepCheckResults` ordered by `created_at` (`cloud_firestore`), or `GET /history`, in `startSession()` |

**Shared device.** At every login `HomeShell` calls `AppServices.startSession(uid)`. If it's a
different person from the last one, the saved details and this session's results are dropped
*before* the first tab is drawn, so the next person never sees them (`test/session_test.dart` and
the "next person never sees" widget test). The same person logging back in keeps them.

**Saving the profile to Firestore (U2).** Create Account asks **date of birth**, sex and contact
(the only place they are asked). The call sites are already in place, so you only fill in the
bodies in `services/profile_service.dart`:
- `saveAccount(uid: ...)` is called by `register()` through `onCreated`, **while the new user is
  still signed in** (just before its `signOut()`), which is when the rules allow the write.
- `load(uid)` is called at every login by `startSession()`; read `users/{uid}` and set `details`.
- `saveProfile` / `saveHistory` / `saveLifestyle` / `saveLastWeight` run while signed in; use `uid`.

Store `dateOfBirth` (a timestamp) instead of
`userAge`: the rules currently require `userAge` (18-120) and allow only 5 fields, so extend
`validProfile` in `firebase/firestore.rules` with type/range checks for every new field, and update
`docs/DATABASE.md` and the ERD. Needs `flutter pub add cloud_firestore` and, in `main.dart`,
`FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost(), 8080);`.

The API address for each device is in `config/api_config.dart` (`127.0.0.1:8000` for Chrome,
`10.0.2.2:8000` for the Android emulator, `--dart-define=API_URL=...` to override). The API allows
browser calls from any `localhost`/`127.0.0.1` port (CORS, `backend/app/main.py`); add a hosted web
address with the `CORS_ORIGINS` environment variable.

---

## 5. Moving to a real Firebase project

1. Create the project (see `docs/DATABASE.md` §7).
2. `flutterfire configure` in `mobile/` → generates `lib/firebase_options.dart`.
3. In `firebase_config.dart`, make `firebaseOptions()` return
   `DefaultFirebaseOptions.currentPlatform`.
4. Run with `--dart-define=USE_EMULATOR=false`.

---

## 6. Design notes (mockup vs. built)

Every difference from the mockups, and every placeholder, is listed in `docs/UI_GUIDE.md` §9.
Fonts come from `google_fonts` (Poppins, Young Serif, Lato) and need internet the first time.
