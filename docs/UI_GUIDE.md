# UI Skeleton Guide (Section 3.5.4 → Flutter)

This guide goes with the Flutter code in `mobile/lib/`. It turns every interface mockup in
**Section 3.5.4 (Figures 3.15–3.24)** of the final report into a screen that runs. Read it top to
bottom once, then use §6 (the mapping table) to find code later.

For running the app and the Firebase emulator, see also `docs/MOBILE_GUIDE.md`.

**Contents:**
1. Summary of Section 3.5.4
2. Checklist of screens and components
3. Project structure
4. Where the code is
5. Running and modifying the app
6. Component mapping guide (mockup → file → widget)
7. Flutter concepts, explained with this project
8. Practice exercises
9. Final checklist: what is done and what is not

---

## 1. Summary of Section 3.5.4

Section 3.5.4 has **10 interface mockups** (report pages 97–101). The flowchart in Figure 3.25
(page 102) shows how they connect.

| # | Figure | Interface | What the report says it contains |
|---|---|---|---|
| 1 | 3.15 | Login | Email and password fields, a forgot-password link, a way to create an account |
| 2 | 3.16 | Create Account | First and last name, email, password, contact number, age, sex |
| 3 | 3.17 | Forgot Password | Email input that triggers password-reset instructions |
| 4 | 3.18 | Main | Welcome screen with two actions (Predict a Disease, View Prediction History) and health promotion content |
| 5 | 3.19 | Quick Prediction Input | Form for the shared attributes: age, sex, weight, height, BMI, high blood pressure, high cholesterol, alcohol, physical activity, smoking, general health |
| 6 | 3.20 | Quick Prediction Result | Expandable cards showing the risk % for Heart Disease, Diabetes Mellitus and Stroke, each with a Deep Check button |
| 7 | 3.21 | Deep-Check Input (Heart) | Resting BP, cholesterol, fasting blood sugar, max heart rate, ST depression, major vessels, chest pain type |
| 8 | 3.22 | Deep-Check Result (Heart) | Final risk %, a detailed explanation and a disclaimer |
| 9 | 3.23 | History | Past deep-check results grouped by date; each opens its details |
| 10 | 3.24 | Profile | Name, email, profile photo, links to activity, settings, privacy, and logout |

**Flow (Figure 3.25):** Login → Main → Quick Prediction Input → *Check* → AI → Quick Result →
pick a disease → Deep-Check Input → *Deep Check* → AI → Deep-Check Result → saved to the
database → shown in History.

Screens 4–10 share a bottom bar: **Home / History / Profile**.

---

## 2. Checklist of screens and components

All 10 screens are built. ✅ = matches the mockup, 🔶 = a placeholder or assumption (each one is
explained in §9).

| Screen | Components |
|---|---|
| **1 Login** | ✅ green wave · ✅ "Hello" + subtitle · ✅ email field · ✅ password field + eye toggle · ✅ "Forgot your password?" · ✅ LOG IN button · ✅ "Don't have an account? Create" |
| **2 Create Account** | ✅ wave top-left + bottom-left · ✅ title + subtitle · ✅ first/last name side by side · ✅ email · ✅ password (🔶 eye icon moved here from the email row) · ✅ contact number · ✅ age · ✅ Male/Female toggle · ✅ Create Account button |
| **3 Forgot Password** | ✅ back arrow · ✅ serif heading · ✅ grey subtitle · ✅ email field · ✅ Reset Password button |
| **4 Main** | ✅ green header "Welcome back, *name*!" · ✅ Predict a Disease card · ✅ View Prediction History card · 🔶 swipeable banners with dots (drawn, not images) · 🔶 sideways info cards · ✅ bottom bar |
| **5 Quick Input** | ✅ back arrow · ✅ Age / Sex / Weight / Height / BMI boxes (🔶 BMI is calculated) · ✅ 4 YES/NO radio rows · ✅ Smoking Status + General Health dropdowns · ✅ Check button · ✅ bottom bar |
| **6 Quick Result** | ✅ back arrow · ✅ 3 expandable cards, highest risk first · ✅ summary sentence · ✅ Deep Check button · ✅ bottom bar |
| **7 Deep-Check Input** | ✅ back arrow + disease title · ✅ 2-column number boxes · ✅ Sex box · ✅ YES/NO row · ✅ Chest Pain Type dropdown · ✅ Deep Check button · 🔶 Diabetes and Stroke versions (no mockup) |
| **8 Deep-Check Result** | ✅ circle with tick · ✅ big coloured % · ✅ expandable card with explanation + disclaimer · ✅ bottom bar |
| **9 History** | ✅ serif "History" title · ✅ date headings (Today, 10 May…) · ✅ "Diagnosis N" cards with arrow · ✅ tap → full result · 🔶 second line shows disease + % |
| **10 Profile** | ✅ green ring photo + camera badge (🔶 badge shows a message) · ✅ name + email · ✅ Edit Profile pill (🔶 message) · ✅ My Activity / Settings / Privacy & Security card (🔶 messages) · ✅ separate Log out card with confirmation (works) |

---

## 3. Project structure

The code is split into **MVC-style** folders. Each folder has one job, so you always know where to
look:

| Folder | MVC role | Holds | Rule |
|---|---|---|---|
| `models/` | **M**odel | Plain data: `Disease`, `RiskResult`, `HistoryEntry`, the deep-check question lists | No widgets, no Firebase |
| `screens/` + `widgets/` | **V**iew | What you see | No Firebase or HTTP calls; ask a service instead |
| `services/` | **C**ontroller | Login, predictions, history: everything that talks to the outside world | No widgets |
| `theme/` | View settings | Every colour and font | Screens say `AppColors.green`, never `Color(0xFF...)` |
| `navigation/` | Glue | Which tab is selected | |

```
mobile/lib/
├── main.dart                         start-up: Firebase → emulator → runApp(App)
├── app.dart                          MaterialApp + theme + first screen (AuthGate)
├── config/firebase_config.dart       emulator now, real Firebase later
├── theme/app_theme.dart              AppColors, AppFonts (Poppins / Young Serif / Lato), AppTheme
├── models/
│   ├── disease.dart                  Disease enum, RiskLevel (low/moderate/high), RiskResult
│   ├── history_entry.dart            one saved deep-check result
│   └── deep_check_form.dart          the questions for each disease's deep-check form
├── navigation/app_tabs.dart          Home=0, History=1, Profile=2 + goTo()
├── services/
│   ├── app_services.dart             bundles the 3 services so screens get them in one parameter
│   ├── auth_service.dart             login, register, reset password, logout (Firebase Auth)
│   ├── prediction_service.dart       DUMMY quick + deep predictions (to be replaced by FastAPI)
│   └── history_service.dart          DUMMY in-memory history (to be replaced by Firestore)
├── screens/                          one file per mockup
│   ├── auth_gate.dart                signed out → Login · signed in → HomeShell
│   ├── home_shell.dart               the 3 tab pages + bottom bar
│   ├── login_screen.dart             1  (Fig 3.15)
│   ├── create_account_screen.dart    2  (Fig 3.16)
│   ├── forgot_password_screen.dart   3  (Fig 3.17)
│   ├── main_screen.dart              4  (Fig 3.18)  Home tab
│   ├── quick_prediction_input_screen.dart   5  (Fig 3.19)
│   ├── quick_prediction_result_screen.dart  6  (Fig 3.20)
│   ├── deep_check_input_screen.dart  7  (Fig 3.21)  serves all 3 diseases
│   ├── deep_check_result_screen.dart 8  (Fig 3.22)
│   ├── history_screen.dart           9  (Fig 3.23)  History tab
│   └── profile_screen.dart           10 (Fig 3.24)  Profile tab
└── widgets/                          pieces used by more than one screen
    ├── primary_button.dart           the green button (LOG IN, Check, Deep Check…)
    ├── rounded_field.dart            pill-shaped text field with icon (login/sign-up)
    ├── wave_header.dart              green waves (WaveHeader, BottomCornerWave)
    ├── app_back_button.dart          the black ← arrow
    ├── app_bottom_nav.dart           Home / History / Profile bar
    ├── labeled_box.dart              "label above white box" (number, choice, 2-column grid)
    ├── yes_no_table.dart             NO / YES radio table
    ├── labeled_dropdown.dart         square dropdown with serif label
    ├── expandable_card.dart          card that opens/closes (results)
    ├── menu_card.dart                profile menu rows
    ├── phone_width.dart              keeps screens phone-width in a wide browser
    └── coming_soon.dart              "X is not designed yet" message
mobile/test/auth_flow_test.dart       11 widget tests covering every flow
```

**How the screens connect:**

```
AuthGate ──signed out──► LoginScreen ──push──► CreateAccountScreen
   │                         └────────push──► ForgotPasswordScreen
   └──signed in──► HomeShell  [ Home | History | Profile ]  (IndexedStack + AppBottomNav)
                     Home (MainScreen) ──push──► QuickPredictionInput ──push──► QuickPredictionResult
                                                   ──push──► DeepCheckInput ──replace──► DeepCheckResult
                     History ──push──► DeepCheckResult (tab = History)
                     Profile ──Log out──► signOut() → AuthGate shows Login by itself
```

- **push** puts a new screen on top, so back returns to the previous one.
- **replace** (`pushReplacement`) swaps the current screen for a new one. The Deep-Check form is
  replaced by its result, so pressing back can't submit the form twice.
- Tapping any bottom-bar icon calls `AppTabs.goTo`. It closes every pushed screen and switches tab.

---

## 4. Where the code is

Every file listed in §3 is complete and compiles. Each file starts with a comment block showing
the mockup as a small text sketch, and the code has teaching comments. The best reading order
for learning:

1. `theme/app_theme.dart` (colours and fonts)
2. `widgets/primary_button.dart` (a small reusable widget)
3. `screens/login_screen.dart` (a full screen with a form)
4. `screens/home_shell.dart` + `widgets/app_bottom_nav.dart` (tabs)
5. `screens/quick_prediction_input_screen.dart` (a form with state)
6. `models/deep_check_form.dart` + `screens/deep_check_input_screen.dart` (a screen built from data)

---

## 5. Running and modifying the app

All commands are for PowerShell.

### 5.1 First time

```powershell
cd C:\fyp\FinalYearProjectUiTM\mobile
flutter pub get
```
**Why:** this downloads the packages listed in `pubspec.yaml` (firebase_auth, google_fonts…).
Run it again whenever `pubspec.yaml` changes, or when VS Code shows red errors like
"Target of URI doesn't exist".

### 5.2 Run in Chrome (easiest)

**Terminal 1: Firebase emulator.** The login screens need it.
```powershell
cd C:\fyp\FinalYearProjectUiTM\firebase
$env:JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=C:/fyp/tmp"
firebase emulators:start --import ./emulator-data --export-on-exit
```
**Why:** the app logs in against this local fake Firebase. The `JAVA_TOOL_OPTIONS` line stops
the "Unable to establish loopback connection" crash.

**Terminal 2: the app.**
```powershell
cd C:\fyp\FinalYearProjectUiTM\mobile
flutter run -d chrome
```
Log in with a seeded demo account. The emails are in `backend/db_tool.py`; the password is
`DEMO_PASSWORD` in the same file.

To make the browser **look like a phone**: press F12 → click the phone/tablet icon
(Toggle device toolbar) → pick "iPhone 14 Pro" or similar. The mockups are 393 × 852.

While it runs:
- **r** = hot reload. Your UI change appears in about 1 s and you stay on the same screen.
- **R** = hot restart. Use it after changing `initState`, models or services.
- **q** = quit.

### 5.3 Run on an Android emulator or phone

```powershell
flutter emulators                       # list the virtual phones you created in Android Studio
flutter emulators --launch <id>         # start one
flutter devices                         # check Flutter can see it (or a USB phone)
flutter run -d <device-id>
```
**Why:** `-d` chooses the device. The app already uses `10.0.2.2` on the Android emulator,
which is how the emulator reaches your PC. On a real phone over Wi-Fi, see `docs/MOBILE_GUIDE.md` §1.
An iPhone needs a Mac with Xcode, so on Windows use Chrome or Android.

### 5.4 Check your changes

```powershell
flutter analyze   # expect: No issues found!
flutter test      # expect: All tests passed!  (11 tests, no emulator needed)
```

### 5.5 Common errors

| You see | Cause | Fix |
|---|---|---|
| Yellow-and-black stripes + "RenderFlex overflowed" | Content too big for its Row/Column | Wrap the widget in `Expanded`/`Flexible`, shorten the text, or make the page a `ListView` |
| "Target of URI doesn't exist" | Packages not downloaded | `flutter pub get` |
| Login spins, then "Could not reach the server" | Emulator not running | Start Terminal 1 (§5.2) |
| Text appears in a plain font for a second | Google Fonts are downloading (needs internet the first time) | Normal; they're cached afterwards |
| Change doesn't appear after **r** | You changed `initState`, a model or a service | Press **R** |
| "setState() called after dispose()" | A screen updated itself after it was closed | Check `if (!mounted) return;` after every `await` (see `_check()` in the quick input screen) |
| Test fails with "Bad state: No element" | A `find.byKey(...)` didn't find the widget | Check the `Key('...')` name, or it is off-screen: use `scrollAndTap` |

### 5.6 Finding the code for something you see

1. Look up the screen in §6 to get the file.
2. In VS Code press **Ctrl+P**, type the file name and press Enter.
3. Press **Ctrl+F** and search for the **text you see on screen**, e.g. `'Deep Check'`.
4. **Ctrl+Click** a widget name, e.g. `PrimaryButton`, to jump to where it is defined.

### 5.7 A first small change, step by step

Goal: make the **Check** button on the Quick Prediction screen wider.

1. Open `lib/screens/quick_prediction_input_screen.dart`.
2. Search for `'Check'`. You'll find `PrimaryButton(label: 'Check', width: 172, height: 46, …)`.
3. Change `width: 172` to `width: 260`. Save.
4. In the terminal running `flutter run`, press **r**.
5. Open the Quick Prediction screen. The button is wider.

---

## 6. Component mapping guide

"What I can modify" lists the parameters to edit. Everything else stays the same.

### 1 · Login (Fig 3.15) → `screens/login_screen.dart`

| Mockup element | File | Widget / class | Purpose | What I can modify |
|---|---|---|---|---|
| Green wave | `widgets/wave_header.dart` | `WaveHeader` | Decoration | `height`, `widthFactor`, wave shape in `_WavePainter` |
| "Hello" / "Sign in…" | login_screen | `Text` + `AppFonts.title/body` | Heading | text, `size`, colour |
| E-mail / Password | `widgets/rounded_field.dart` | `RoundedField` | Input | `hint`, `icon`, `validator`, `keyboardType` |
| Eye icon | login_screen | `PasswordEyeButton` | Show/hide password | icon in the widget |
| Forgot your password? | login_screen | `TextButton` → `_openForgotPassword` | Navigate | text, style |
| LOG IN | `widgets/primary_button.dart` | `PrimaryButton` | Submit (`_submit`) | `label`, `width`, `height`, `uppercase`, `fontSize` |
| Don't have an account? Create | login_screen | `Wrap` + `GestureDetector` | Navigate | text |
| Error popup | login_screen | `showErrorDialog()` | Shows login failures | title/message |

### 2 · Create Account (Fig 3.16) → `screens/create_account_screen.dart`

| Mockup element | File | Widget / class | Purpose | What I can modify |
|---|---|---|---|---|
| Top-left wave | wave_header | `WaveHeader(height: 115, widthFactor: 0.6)` | Decoration | `height`, `widthFactor` |
| Bottom-left wave | wave_header | `BottomCornerWave` | Decoration | `width`, `height` |
| First / Last name | rounded_field | `RoundedField` inside `Row` + `Expanded` | Two halves of one row | gap `SizedBox(width: 14)` |
| E-mail, Password, Contact, Age | rounded_field | `RoundedField` | Inputs | validators (`_required`, age 18–120) |
| Male / Female | create_account_screen | `_SexToggle` | Choice | colours, `height: 34`, radius |
| Create Account | primary_button | `PrimaryButton(width: 260)` | Calls `auth.register` | label, size |

### 3 · Forgot Password (Fig 3.17) → `screens/forgot_password_screen.dart`

| Mockup element | File | Widget / class | Purpose | What I can modify |
|---|---|---|---|---|
| ← | `widgets/app_back_button.dart` | `AppBackButton` | `Navigator.pop` | icon, size |
| Forgot Password? | forgot_password_screen | `FittedBox` + `AppFonts.serif(size: 34)` | Heading | size, text |
| Enter your email | rounded_field | `RoundedField` | Input | hint |
| Reset Password | primary_button | `PrimaryButton` | Calls `auth.sendPasswordReset` | label, width |

### 4 · Main (Fig 3.18) → `screens/main_screen.dart`

| Mockup element | File | Widget / class | Purpose | What I can modify |
|---|---|---|---|---|
| Green header | main_screen | `_Header` | Greeting | `padding`, `Radius.elliptical(220, 70)` curve, font size |
| Predict a Disease card | main_screen | `_ActionCard` (lavender) | Push Quick Input | `background`, `icon`, `title`, `subtitle`, `onTap` |
| View Prediction History card | main_screen | `_ActionCard` (mint) | Switch to History tab | same |
| Banner carousel + dots | main_screen | `_BannerCarousel`, `_Banner`, `_banners` list | Health promotion | add/remove entries in `_banners`, `viewportFraction`, `height: 170` |
| Blue/red info cards | main_screen | `_InfoCardRow` | Health promotion | `_cards` list, `width: 315` |
| Bottom bar | `widgets/app_bottom_nav.dart` | `AppBottomNav` | Tabs | icons, labels, colours |

### 5 · Quick Prediction Input (Fig 3.19) → `screens/quick_prediction_input_screen.dart`

| Mockup element | File | Widget / class | Purpose | What I can modify |
|---|---|---|---|---|
| Age / Weight / Height / BMI boxes | `widgets/labeled_box.dart` | `LabeledNumberBox` | Number input | `label`, `suffix` ("KG"), `decimal`, `readOnly` |
| Sex box | labeled_box | `LabeledChoiceBox` | Choice | `options` |
| Two-column layout | labeled_box | `TwoColumnGrid` | Layout | `gap`, `rowGap` |
| Box look (all boxes) | labeled_box | `_Pill` | White rounded shadow box | `height: 52`, `circular(18)`, padding |
| YES/NO rows | `widgets/yes_no_table.dart` | `YesNoTable` | Radio answers | the `_yesNo` map in the screen (add/remove questions) |
| Smoking / General Health | `widgets/labeled_dropdown.dart` | `LabeledDropdown` | Choice | `options` lists |
| Check | primary_button | `PrimaryButton(key: 'quickCheck')` | Calls `predictions.quickPredict` | label, size |
| BMI calculation | quick input screen | `_updateBmi()` | weight ÷ height² | formula, decimals |

### 6 · Quick Prediction Result (Fig 3.20) → `screens/quick_prediction_result_screen.dart`

| Mockup element | File | Widget / class | Purpose | What I can modify |
|---|---|---|---|---|
| Disease cards | `widgets/expandable_card.dart` | `ExpandableCard` | Open/close | `title`, `trailingText`, `initiallyExpanded`, padding, radius |
| "Your responses indicate…" | `services/prediction_service.dart` | `PredictionService.quickSummary` | Sentence | wording |
| Deep Check | primary_button | `PrimaryButton(width: 126, height: 32)` | Push Deep-Check Input | size |
| Order of cards | prediction_service | `results.sort(...)` | Highest risk first | sort rule |

### 7 · Deep-Check Input (Fig 3.21) → `screens/deep_check_input_screen.dart` + `models/deep_check_form.dart`

| Mockup element | File | Widget / class | Purpose | What I can modify |
|---|---|---|---|---|
| Questions per disease | `models/deep_check_form.dart` | `DeepCheckForm.forDisease` | List of questions | add/remove `NumberQuestion`, `YesNoQuestion`, `ChoiceQuestion` |
| ← + "Heart Disease" | deep_check_input_screen | `Row(AppBackButton, FittedBox(Text))` | Title | `AppFonts.serif(size: 34)` |
| Number boxes + Sex | labeled_box | `LabeledNumberBox`, `LabeledChoiceBox` via `_gridBoxes()` | Inputs | order in `_gridBoxes()` |
| High Blood Pressure? | yes_no_table | `YesNoTable` | Radio | — |
| Chest Pain Type | labeled_dropdown | `LabeledDropdown` in `FractionallySizedBox(widthFactor: 0.7)` | Choice | width factor |
| Deep Check | primary_button | `PrimaryButton(key: 'deepCheckSubmit')` | Calls `predictions.deepCheck`, then `history.add` | size |

### 8 · Deep-Check Result (Fig 3.22) → `screens/deep_check_result_screen.dart`

| Mockup element | File | Widget / class | Purpose | What I can modify |
|---|---|---|---|---|
| Circle with tick | deep_check_result_screen | `Container(shape: circle, border)` + `Icon(Icons.check)` | Done indicator | `175` size, border width/colour |
| 80% | deep_check_result_screen | `Text` with `result.level.color` | Risk | `size: 64` |
| Risk colour | `models/disease.dart` | `RiskLevel.fromPercent` | red/orange/green | thresholds (60 / 30) |
| Explanation card | expandable_card | `ExpandableCard(initiallyExpanded: true)` | Details + disclaimer | text in `PredictionService.deepExplanation` |

### 9 · History (Fig 3.23) → `screens/history_screen.dart`

| Mockup element | File | Widget / class | Purpose | What I can modify |
|---|---|---|---|---|
| "History" | history_screen | `Text` + `AppFonts.serif(size: 40)` | Title | size |
| Today / 10 May | history_screen | `_dateHeading()` | Group by date | format, month names |
| Diagnosis cards | history_screen | `_HistoryCard` | Opens result | margin, radius, second line text |
| Data | `services/history_service.dart` | `HistoryService.entries` (`ValueNotifier`) | List of results | sample entries in `_sampleEntries()` |

### 10 · Profile (Fig 3.24) → `screens/profile_screen.dart`

| Mockup element | File | Widget / class | Purpose | What I can modify |
|---|---|---|---|---|
| Green ring + camera | profile_screen | `_ProfilePhoto` (`Stack` + `Positioned`) | Photo | `size: 165`, ring width, badge position |
| Name / email | profile_screen | `Text` | Shows user | sizes |
| Edit Profile | profile_screen | `_GreyPillButton` | Placeholder | colour, padding |
| My Activity / Settings / Privacy | `widgets/menu_card.dart` | `MenuCard` + `MenuItem` | Placeholders | `icon`, `label`, `onTap` |
| Log out | menu_card | `MenuItem(key: 'logout')` → `_confirmLogout` | Sign out | dialog text |

---

## 7. Flutter concepts, explained with this project

**Everything is a widget.** A screen is a tree of small widgets inside each other. "Change
something" usually means "find the widget and change one of its parameters".

**Layout widgets.** These are the ones you'll touch most:

| Widget | What it does | Use it when | Example in this project |
|---|---|---|---|
| `Container` | A box that can have size, padding, margin, colour, border, radius, shadow | You need a **visible** box | `_Pill` in `labeled_box.dart` |
| `Padding` | Only adds empty space around its child | You just need space (lighter than `Container`) | `Padding(padding: EdgeInsets.all(14), …)` in `_ActionCard` |
| `SizedBox` | A fixed size, or an empty gap | Gaps between widgets, fixed button size | `SizedBox(height: 24)`; `PrimaryButton` |
| `Column` | Children top → bottom | Vertical lists that don't scroll | label + box in `LabeledNumberBox` |
| `Row` | Children left → right | Things side by side | first/last name |
| `Expanded` | Inside a Row/Column: "take the leftover space" (shared equally) | Two equal halves; push something to the far side | `TwoColumnGrid`, `_MenuRow` label |
| `ListView` | A Column that scrolls | Whole pages | every screen |
| `Stack` + `Positioned` | Widgets on top of each other | Badges, decorations behind content | camera badge, waves |
| `Card` / `Material` + `InkWell` | Surface with a tap ripple | Tappable cards | `_ActionCard`, `_HistoryCard` |

**Padding vs margin:** *padding* is space **inside** the box's border, *margin* is space
**outside** it. `ExpandableCard` uses `margin: EdgeInsets.only(bottom: 12)` to separate cards.

**Changing a box:**
```dart
Container(
  width: 200,                                   // width
  padding: const EdgeInsets.all(16),            // space inside
  margin: const EdgeInsets.only(bottom: 12),    // space outside
  decoration: BoxDecoration(
    color: Colors.white,                        // fill
    border: Border.all(color: Colors.grey, width: 1), // border
    borderRadius: BorderRadius.circular(18),    // rounded corners
    boxShadow: AppTheme.softShadow,             // shadow
  ),
  child: ...,
)
```

**StatelessWidget vs StatefulWidget**
- **Stateless:** shows what it's given and never changes by itself. Examples: `PrimaryButton`,
  `MainScreen`, `HistoryScreen`.
- **Stateful:** remembers values that change while it's on screen and redraws when you call
  `setState(() { ... })`. Examples: `ExpandableCard` (open/closed), the input screens (typed
  values, YES/NO answers), `_BannerCarousel` (current page).
- Rule of thumb: if something on the screen changes when the user taps it, the widget that owns
  that value must be Stateful.

**Changing a button.** `PrimaryButton` has parameters for everything:
```dart
PrimaryButton(
  label: 'Check',      // text
  width: 172,          // size
  height: 46,
  fontSize: 15,
  onPressed: _check,   // action: the function that runs on tap
)
```
The colour is set once in `primary_button.dart` (`backgroundColor: AppColors.green`), so every
green button changes together. Exercise 6 adds a per-button colour.

**Reusing widgets.** When the same look appears twice, it goes in `widgets/` with parameters
for the parts that differ (`LabeledNumberBox(label:, suffix:)`). When a look is used on only
one screen, it stays in that screen's file as a **private** class whose name starts with `_`
(`_ActionCard`, `_SexToggle`). The `_` means other files can't use it.

**Navigation.** `Navigator.push(MaterialPageRoute(builder: (_) => NextScreen()))` opens a
screen and `Navigator.pop(context)` closes it. Tabs don't use the Navigator: `HomeShell` keeps
all three tab pages alive in an `IndexedStack` and shows the one in `AppTabs.current`.

**Services and dummy data.** Screens never call Firebase or the AI directly. They call
`services.predictions.quickPredict(...)`. Today that function returns the mockup's numbers.
Later you replace only the function body with an HTTP call to FastAPI, and **no screen changes**.

**Keys.** `Key('quickCheck')` is a name the tests use to find a widget. It changes nothing on
screen.

---

## 8. Practice exercises

Try each one before opening the solution. After each change, press **r** in the running app and
look at the screen. Then run `flutter test` to check nothing else broke.

### Exercise 1 · Resize a button
**File:** `screens/quick_prediction_input_screen.dart` · **Widget:** `PrimaryButton` (Check)
**Do:** make the Check button 260 wide and 56 tall.
**Observe:** the button grows and stays centred.
<details><summary>Solution</summary>

```dart
PrimaryButton(key: const Key('quickCheck'), label: 'Check', width: 260, height: 56, ...)
```
It stays centred because it sits inside `Center(...)`.
</details>

### Exercise 2 · Change the app's green everywhere
**File:** `theme/app_theme.dart` · **Class:** `AppColors`
**Do:** change `green` to a blue such as `Color(0xFF2F80ED)`. Then change it back.
**Observe:** buttons, waves, the Main header and the selected tab all change. This is why
screens never write colours directly.
<details><summary>Solution</summary>

```dart
static const green = Color(0xFF2F80ED);
```
Use **R** (hot restart) if a colour doesn't update, because `const` values are sometimes cached.
</details>

### Exercise 3 · Make the input boxes rounder and taller
**File:** `widgets/labeled_box.dart` · **Widget:** `_Pill`
**Do:** set the height to 60 and the corner radius to 30.
**Observe:** every box on the Quick Input **and** Deep-Check screens changes, because both use
`_Pill`.
<details><summary>Solution</summary>

```dart
height: 60,
...
borderRadius: BorderRadius.circular(30),
```
</details>

### Exercise 4 · Add a YES/NO question
**File:** `screens/quick_prediction_input_screen.dart` · **Field:** `_yesNo` map
**Do:** add "Diabetes in Family?" with the default answer NO.
**Observe:** a new radio row appears, and its answer is sent to `quickPredict` in `answers`.
You wrote no layout code.
<details><summary>Solution</summary>

```dart
final Map<String, bool> _yesNo = {
  'High Blood Pressure?': true,
  'High Cholesterol?': true,
  'Alcohol Consumption': false,
  'Physical Activity Level': true,
  'Diabetes in Family?': false,
};
```
</details>

### Exercise 5 · Add a question to the Stroke deep check
**File:** `models/deep_check_form.dart` · **Method:** `forDisease`, `Disease.stroke`
**Do:** add a number question "Average Glucose" (sample `105`, decimals allowed) and a YES/NO
"Heart Disease?".
**Observe:** open Quick Result → Stroke → Deep Check. The new boxes appear. The screen file
didn't change, because it builds itself from this list.
<details><summary>Solution</summary>

```dart
Disease.stroke => const DeepCheckForm(
  numbers: [
    NumberQuestion('Age', sample: '58'),
    NumberQuestion('BMI', sample: '41.5', decimal: true),
    NumberQuestion('Glucose Level', sample: '140'),
    NumberQuestion('Average Glucose', sample: '105', decimal: true),
  ],
  yesNo: [YesNoQuestion('Hypertension?', sample: true), YesNoQuestion('Heart Disease?')],
  choices: [_sex, _smoking],
),
```
</details>

### Exercise 6 · Give PrimaryButton a colour option (reusable widgets)
**File:** `widgets/primary_button.dart` · **Class:** `PrimaryButton`
**Do:** add an optional `color` parameter that defaults to `AppColors.green`. Then make the
**Reset Password** button red (`AppColors.riskHigh`).
**Observe:** only that button is red; every other button stays green.
<details><summary>Solution</summary>

```dart
// 1. constructor
this.color = AppColors.green,
// 2. field
final Color color;
// 3. in build
backgroundColor: color,
disabledBackgroundColor: color.withValues(alpha: 0.6),
```
In `forgot_password_screen.dart`:
```dart
PrimaryButton(key: const Key('resetPassword'), label: 'Reset Password',
    color: AppColors.riskHigh, ...)
```
A default value must be a constant. `AppColors.green` qualifies because it is declared
`static const`.
</details>

### Exercise 7 · Add a banner to the Main screen
**File:** `screens/main_screen.dart` · **List:** `_banners`
**Do:** add a fourth banner, e.g. "World Heart Day / September 29" in green.
**Observe:** you can swipe to a fourth page and a fourth dot appears.
<details><summary>Solution</summary>

```dart
(
  'September 29',
  'WORLD HEART DAY',
  'Use your heart: move more, eat well, stop smoking.',
  [Color(0xFF66BB6A), Color(0xFF2E7D32)],
  Icons.monitor_heart,
),
```
</details>

### Exercise 8 (stretch) · Change the risk thresholds
**File:** `models/disease.dart` · **Method:** `RiskLevel.fromPercent`
**Do:** make "high" start at 50% instead of 60%.
**Observe:** the Quick Result sentence for Heart Disease (50%) now says "high risk", and the
colour of matching History results changes. Your supervisor may want these numbers in the report.
<details><summary>Solution</summary>

```dart
if (percent >= 50) return RiskLevel.high;
```
</details>

---

## 9. Final checklist: what is done and what is not

### Done and checked
- [x] All 10 interfaces from Section 3.5.4, with navigation matching Figure 3.25
- [x] Bottom bar on the 7 screens that have it in the mockups; tab switching closes pushed screens
- [x] Login, Create Account (Firebase Auth), Forgot Password (reset email), Logout with confirmation
- [x] Quick prediction → results → deep check → result → saved to History, using dummy data
- [x] Deep-check form for all 3 diseases from one data-driven screen
- [x] Fonts from the mockups (Poppins, Young Serif, Lato via `google_fonts`)

**How it was checked (2026-10-15):**
- `flutter analyze` reports no issues.
- `flutter test`: 11 widget tests pass. They cover login validation, wrong password, the eye
  toggle, create account, forgot password, logout, quick → deep → History, opening a closed
  result card and the Diabetes form, and the Main → History card.
- `flutter build web --debug` succeeds. Screens 1–10 were compared side by side with the mockup
  PNGs in Chrome at 393 × 852, logged in to the Auth emulator with a seeded account. Found and
  fixed this way: "Deep Check" wrapping onto two lines, cut-off name hints, the Main header
  height, a clipped decoration, and "a 80%" → "an 80%".
- **Not checked:** running on an Android emulator or real phone; the Stroke form and the
  Create Account fixes were only checked by tests, not by eye.

### Placeholders and assumptions (decide or replace later)

| # | Item | Now | To make it real |
|---|---|---|---|
| 1 | AI predictions | `PredictionService` returns fixed numbers (heart 50/80, diabetes 40/62, stroke 20/35) | Replace the bodies with `http` calls to FastAPI `POST /predict/quick` and `/predict/deep/{disease}` (`docs/MOBILE_GUIDE.md` §4) |
| 2 | History storage | In memory; 7 sample entries; lost on restart | Read/write Firestore `users/{uid}/deepCheckResults`, or call `GET /history` |
| 3 | Contact, age, sex at sign-up | Validated but **not saved** | Add `cloud_firestore`, write `users/{uid}` (MOBILE_GUIDE §4 step 4) |
| 4 | Quick form fields | 11 fields as in the mockup | The backend model needs **19 BRFSS features** (`backend/app/schemas.py`). The form, the report and the model must be aligned (CLAUDE.md "Known issues") |
| 5 | Diabetes / Stroke deep-check forms | Built from the data dictionary (no mockup) | Confirm the fields with your supervisor; edit `deep_check_form.dart` |
| 6 | Banners and info cards | Drawn with gradients and icons, because the mockup uses third-party posters | Add your own images to `assets/` and use `DecorationImage` (comment in `_Banner`) |
| 7 | Edit Profile, camera badge, My Activity, Settings, Privacy & Security, banner taps | Show "… is not designed yet." | Need mockups or descriptions first |
| 8 | Risk colours and words | below 30 low, 30–60 moderate, above 60 high | Not in the report; agree on thresholds |
| 9 | History card second line | Shows disease + % (empty in mockup) | Remove the `Text` in `_HistoryCard` if you prefer the mockup exactly |
| 10 | Eye icon on Create Account | On Password (the mockup shows it on E-mail) | Looks like a mockup slip |
| 11 | "120 KG" | The number is centred and "KG" sits at the right edge | Cosmetic |
| 12 | Back arrow on Deep-Check Result | None (as in the mockup); leave via the bottom bar or system back | Add `AppBackButton` if users get stuck |
| 13 | Profile photo | Empty ring | Needs Firebase Storage + image picker |
| 14 | The Auth emulator's "Running in emulator mode" strip on web | Covers the bottom bar in Chrome | Disappears with a real Firebase project |
