# Lifestyle Check, Profile and History: questions, levels and mappings (task U1)

Created 2026-10-29. Status: **CHECKPOINT 6 approved 2026-10-29**. Income (item 6) filled 2026-11-11
with DOSM HIES 2022 points; saving (section D) built 2026-11-11.

Rule: each answer must map **exactly** to what the model was trained on, without changing the
reading's meaning. For each reading below:
1. what it really means in the training data;
2. the question the app asks;
3. the levels shown to the user;
4. exactly what is sent to the API.

Mappings marked ⚠️ cannot map cleanly; each needs your decision. **No API or model change is needed:**
the app converts answers into the values the API already accepts (`backend/app/schemas.py`).

---

## A. Lifestyle check (readings 15-19, retakeable)

### 15. Smoking
**In the training data**
- **Quick** (BRFSS `Smoker`): "Have you smoked at least 100 cigarettes in your entire life?"
  (100 cigarettes = about 5 packs). Yes = 1.
- **Stroke** (`smoking_status`): never smoked / formerly smoked / smokes / Unknown.
- **Diabetes** (`smoking_history`): never / former / current / not current / ever / No Info.

**Questions**
1. *Have you smoked at least 100 cigarettes (about 5 packs) in your whole life?* Yes / No
2. *Do you smoke cigarettes now, every day or on some days?* Yes / No

| Q1 | Q2 | Level shown | Quick `smoked_100_cigarettes` | Stroke `smoking_status` | Diabetes `smoking_history` |
|---|---|---|---|---|---|
| Yes | Yes | Current smoker | true | `smokes` | `current` |
| Yes | No | Former smoker | true | `formerly smoked` | `former` |
| No | Yes | New / light smoker | false | `smokes` | `current` |
| No | No | Never smoked | false | `never smoked` | `never` |

⚠️ **S1. Vape / e-cigarettes:** all three datasets count **cigarettes only**. A vape-only user maps to
"never smoked", so vaping is not modelled. That is a limitation to state; the question text should say
"cigarettes (not vape)".
⚠️ **S2.** The app never sends `Unknown`, `not current`, `ever` or `No Info`. Those dataset categories
are vaguely defined, so the four clear rows above cover every answer.

### 16. Physical activity
**In the training data:** BRFSS `PhysActivity`: *"During the past month, other than your regular job,
did you take part in any physical activities or exercises such as running, gardening or walking for
exercise?"* **Any** activity = 1. It is yes/no only; how often isn't recorded.

**Question:** *In the past 30 days, not counting your job, how often did you exercise or do physical
activity (e.g. brisk walking, jogging, sports, gardening)?*

| Answer | Level shown (your thresholds) | Quick `physically_active_last_30_days` |
|---|---|---|
| 3 or more times a week | **Active** | true |
| 1-2 times a week | **Semi-active** | true |
| A few times this month (less than weekly) | **Semi-active** | true |
| Not at all | **Inactive** | false |

The three levels are for the user (and advice later). The model only receives yes/no, and **any
activity = yes**, so "semi-active" correctly counts as active for the model. This mapping is exact.

### 17-18. Fruit and vegetables
**In the training data:** BRFSS `Fruits` / `Veggies`: eats fruit / vegetables **1 or more times a day**
(fruit includes 100% fruit juice).

**Questions:** *How often do you eat fruit (fresh, frozen, canned, or 100% fruit juice)?* and *How often
do you eat vegetables (including salad and beans)?*

| Answer | Level shown | Quick `eats_fruit_daily` / `eats_vegetables_daily` |
|---|---|---|
| 2 or more times a day | Daily | true |
| Once a day | Daily | true |
| A few times a week | Less than daily | false |
| Rarely or never | Less than daily | false |

Exact mapping: the cut-off (once a day) is fixed by the data, not a threshold you can move.

### 19. Alcohol
**In the training data:** BRFSS `HvyAlcoholConsump`: heavy drinker = **men > 14 drinks a week,
women > 7**. The API already takes `alcohol_drinks_per_week` and applies this rule with the user's sex.

**Questions**
1. *Do you drink alcohol?* No → 0 drinks a week (most Malaysian users stop here).
2. *In a typical week, how many drinks? (1 drink = 1 can of beer 330 ml, 1 glass of wine 150 ml,
   or 1 shot of spirits 45 ml)*

| Level shown | Rule | Sent |
|---|---|---|
| None | 0 drinks | 0 |
| Moderate | ≤ 14 (men) / ≤ 7 (women) | the number |
| Heavy | > 14 (men) / > 7 (women) | the number |

The heavy cut-off is fixed by the data definition. The drink sizes follow the US "standard drink"
(about 14 g alcohol) that BRFSS uses.

---

## B. Profile (readings 1-9, asked at sign-up, editable)

| # | Reading | Question | Sent to API | Mapping |
|---|---|---|---|---|
| 1 | Age | Date of birth | `age` in years, calculated on the day of each check | exact (the API converts to the 13 BRFSS age bands) |
| 2 | Sex | Male / Female | `sex` | exact |
| 3 | Height | Height in cm | used for BMI | exact |
| 4 | Education | see table E | `education_level` 1-6 | ⚠️ E1 |
| 5 | Income | Monthly household income (RM) | `income_level` 1-8 | percentile matching with DOSM HIES 2022 points (`dosmIncomePercentiles` in `models/api_payloads.dart`); approximate below P20 |
| 6 | Health coverage | see H1 | `has_health_coverage` | ⚠️ H1 |
| 7 | Ever married | *Have you ever been married?* (divorced / widowed = yes) | `ever_married` | exact |
| 8 | Work type | see W1 | `work_type` | ⚠️ W1 |
| 9 | Residence | *Do you live in an urban or rural area?* | `residence_type` | exact (self-identified) |

**Table E: education** (BRFSS codes: 1 none/kindergarten, 2 grades 1-8, 3 grades 9-11, 4 high-school
graduate, 5 some college/technical, 6 college graduate)

| Malaysian answer | Code |
|---|---|
| No formal schooling | 1 |
| Primary school only (Standard 1-6) | 2 |
| Some secondary school, did not complete SPM | 3 |
| SPM (completed Form 5) | 4 |
| STPM, Matriculation, Diploma, certificate, or some university | 5 |
| Bachelor's degree or higher | 6 |

⚠️ **E1.** SPM is 11 years of school, while a US high-school diploma is 12. SPM is mapped to code 4
because it does the same job: it completes secondary school. Mention this equivalence in Chapter 3.

⚠️ **H1. Health coverage.** BRFSS counts *any* coverage, including **government plans**. Malaysian
citizens have tax-funded public healthcare at a nominal fee, which is not insurance but works the same
way. Options:
- **(i)** Citizen **or** has insurance/takaful **or** an employer panel clinic = yes *(recommended: closest
  to the meaning; most users will be "yes", as in BRFSS, where most respondents were covered)*.
- **(ii)** Only private insurance/takaful/panel = yes. Stricter, but it changes the meaning (US public
  coverage counted as yes).

⚠️ **W1. Work type.** The dataset only knows Private / Self-employed / Govt_job / Never_worked
(+ children). Proposed options:

| Answer | Sent |
|---|---|
| Private sector employee | `Private` |
| Self-employed, business owner, gig worker | `Self-employed` |
| Government / public servant (incl. teachers, police, armed forces) | `Govt_job` |
| Never had a paid job | `Never_worked` |

Students, homemakers, retired and unemployed people have no matching category. Proposal: ask *"your
main type of work over your working life"*. Retired or unemployed people answer their past job, and
someone who has never had a paid job answers `Never_worked`. It is an approximation; state it as a
limitation.

## C. History (readings 10-14, "has a doctor ever told you…", editable)

| # | Question | Sent to API | Mapping |
|---|---|---|---|
| 10 | *Has a doctor, nurse or other health professional ever told you that you have high blood pressure?* (not counting only during pregnancy; "borderline" = No, as in BRFSS) | Quick `high_blood_pressure`, Stroke + Diabetes `hypertension` | exact; one answer feeds all three |
| 11 | *…that your blood cholesterol is high?* | Quick `high_cholesterol` | exact |
| 12 | *Have you had your cholesterol checked in the last 5 years?* | Quick `cholesterol_checked_last_5_years` | exact |
| 13 | *…that you have heart disease (coronary heart disease, heart attack or angina)?* | Stroke + Diabetes `heart_disease` | exact |
| 14 | *Do you have serious difficulty walking or climbing stairs?* | Quick `difficulty_walking` | exact |

---

## D. Saving it (your task U2: Firebase profile saving)

**Proposal:** store the user's **raw answers** (e.g. "Former smoker", "RM 6,500", "SPM") and convert
them to model codes **at prediction time** in one Dart function. If a mapping ever changes, nothing
stored goes stale, and that function can be unit-tested.

```
users/{uid}
  userName, userEmail, userSex, userCreate_at      (existing)
  dateOfBirth                                       (replaces userAge, which goes out of date)
  profile:   { heightCm, education, incomeMonthlyRm, healthCoverage, everMarried, workType, residence }
  history:   { highBloodPressure, highCholesterol, cholesterolChecked5y, heartDisease,
               difficultyWalking, updatedAt }
  lifestyle: { smoked100, smokesNow, activity, fruit, vegetables, drinksAlcohol, drinksPerWeek,
               updatedAt }
```

✅ **Built 2026-11-11** exactly as above, plus `contactNumber` and `lastWeightKg` (the last weight, so
the Weight box starts filled). Choices are stored by name (`"spm"`, `"threePlusWeekly"`) and
`drinksPerWeek` only for people who drink. The field names are in one place in the app,
`mobile/lib/services/firestore_maps.dart`; `firebase/firestore.rules` (`validUser`) checks the type
and range of every field; `backend/tests/test_db.py` tests it. `docs/DATABASE.md` §4 shows the layout.
The ERD (Figure 3.14) still needs the same update.

## E. How pre-fill looks (built in U3/U4)
- **Quick Prediction:** a collapsed card at the top, *"Using your saved details · updated 12 Oct ·
  Edit"*. Below it, only the 5 per-check questions. Anything missing in the profile appears as a question
  on the screen, with a tick box *"Save to my profile"*.
- **Deep-Check:** the same card. Heart starts with *"Have you done an exercise stress test recently?"*
- **Lifestyle retake:** a reminder on the Main screen when the answers are older than **N days**.
- **Users who registered before this change:** on their first check, a *"Complete your profile (2 min)"*
  prompt.

---

## CHECKPOINT 6: your decisions
1. **Physical activity levels:** approve the thresholds (3+ a week = Active, less than that but at least
   some activity = Semi-active, none = Inactive)?
2. **Smoking:** accept "cigarettes only, not vape" (S1) as a stated limitation?
3. **Education:** approve table E (SPM → code 4)?
4. **Health coverage:** option (i) or (ii)?
5. **Work type:** approve W1 ("main type of work over your working life")?
6. **Income:** send me DOSM HIES 2022 household income percentiles or deciles (monthly RM). I'll build the
   conversion table.
7. **Retake reminder:** after how many days? (I'd suggest 90.)
8. **Storage:** raw answers + convert at prediction time (D)?

### Decisions (2026-10-29)
1-3, 5, 8: approved as proposed. 4: health coverage **option (i)** (citizen, insurance/takaful or panel
clinic = yes). 7: retake reminder after **90 days**. 6: income **pending**. You will send the DOSM HIES 2022
percentiles; until then the income question is built but its RM-to-band table is a placeholder.

### Change 2026-11-11
Income (item 6): the RM-to-band table uses the DOSM HIES 2022 points P20 RM 3,440, P40 RM 5,250,
P50 RM 6,338, P60 RM 7,694, P80 RM 11,820 and P90 RM 15,867. DOSM publishes no point below P20, so
lower incomes are a straight line from RM 0 (approximate). To be checked against the DOSM report
(or replaced by HIES 2024) before the final run.

### Change 2026-11-04
Profile readings 1-2 (date of birth, sex) and the contact number moved to **Create Account** (the only
place they are asked). In section D, `dateOfBirth` and `contactNumber` are written at registration.
