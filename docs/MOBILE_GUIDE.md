# Mobile App Guide (Flutter)

All 10 interfaces from report Section 3.5.4 are built (predictions and history use dummy data
for now). **`docs/UI_GUIDE.md`** is the main guide to the screens: mockup → file mapping,
Flutter concepts and exercises. This file covers running the app and connecting the real backend.

All commands: PowerShell, inside `C:\fyp\FinalYearProjectUiTM\mobile`.

---

## 1. Run it

**Terminal 1 — Firebase emulators** (the app signs in against them; see `docs/DATABASE.md`):
```powershell
cd C:\fyp\FinalYearProjectUiTM\firebase
firebase emulators:start --import ./emulator-data --export-on-exit
```

**Terminal 2 — the app:**
```powershell
cd C:\fyp\FinalYearProjectUiTM\mobile
flutter run -d chrome
```
Log in with a seeded demo account (`backend/db_tool.py`, created by `python -m backend.db_tool seed`).

While it runs: press **r** for hot reload (instant UI changes, keeps you logged in),
**R** for hot restart, **q** to quit.

The red "Running in emulator mode" strip at the bottom is Firebase's own warning in web debug
builds. It disappears with a real Firebase project.

**On an Android emulator** (once you set one up in Android Studio): `flutter run` and pick it.
The app automatically uses `10.0.2.2` — the Android emulator's address for your PC.
**On a real phone over Wi-Fi:** `flutter run --dart-define=EMULATOR_HOST=<your PC's IP>`
(find it with `ipconfig`), and start the emulators with `--host 0.0.0.0` in `firebase.json`.

**Tests** (no emulator needed, ~5 s): `flutter test` → expect `All tests passed!` (11 tests).
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

## 4. Connecting the real data (what is still dummy)

The screens are finished. Three services still return sample data. Replace their **bodies**
only; screens and tests don't change.

| Service | Now | Replace with |
|---|---|---|
| `PredictionService.quickPredict` | fixed 50/40/20 % | `flutter pub add http`, then `POST /predict/quick` on FastAPI. The form must send **all 19 fields** in `backend/app/schemas.py`; the mockup form has 11 (see UI_GUIDE §9 #4) |
| `PredictionService.deepCheck` | fixed 80/62/35 % | `POST /predict/deep/{disease}` with `Authorization: Bearer ${await auth.idToken()}` so the backend saves it to history |
| `HistoryService` | in-memory list | read `users/{uid}/deepCheckResults` ordered by `created_at` (`cloud_firestore`), or `GET /history` |
| `FirebaseAuthService.register` | saves name only | also write `users/{uid}` (step below) |

**Saving the profile to Firestore** (contact, age, sex from Create Account):
after registering, write `users/{uid}`
(`userName`, `userEmail`, `userAge`, `userSex`, `userCreate_at: FieldValue.serverTimestamp()`).
Needs `flutter pub add cloud_firestore` and, in `main.dart`,
`FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost(), 8080);`.
The security rules **require** age 18–120, sex `male`/`female`, and the account's own email.
The form already checks age 18–120; send sex in lower case. Put this write in a new
`services/profile_service.dart`.

Calling the backend from the app: on **web** use `http://127.0.0.1:8000`; on the **Android
emulator** use `http://10.0.2.2:8000` (same reason as the Firebase emulator).

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
