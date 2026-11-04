# Input Readings Inventory (task I1)

Created 2026-10-28. Status: **CHECKPOINT 5 approved 2026-10-29** (decisions in section 8).

Every reading the app needs, per layer and disease. Sources: the API request definitions
(`backend/app/schemas.py`), how they are converted for the models (`backend/app/conversion.py`,
`backend/app/main.py`) and the model reading lists (`ml/config.py`). Valid ranges are the ones the API
already enforces. Nothing here changes a model or the API.

**How the user gets it:** **S** = self-report (they know or answer it), **H** = home measurement
(scale, tape, home BP monitor, glucose meter), **C** = routine clinic or lab test, **T** = hospital test
(exercise stress test).

**Proposed home:** where the app should collect it so the user types it once.
- **Profile**: stable facts, asked at sign-up, editable in Profile.
- **History**: "has a doctor ever told you…", asked at sign-up, editable.
- **Lifestyle**: the retakeable lifestyle quick check (U1/U3).
- **Each check**: changes over time, so it is asked on the screen; pre-filled with the last value where sensible.

---

## 1. Quick Prediction (Layer 1, one model for 3 diseases): 20 inputs → 19 model features

| # | Reading (API field) | Model feature and encoding | Type, unit | Valid range | How | Proposed home | In current form? |
|---|---|---|---|---|---|---|---|
| 1 | Age (`age`) | `Age`: 13 bands (1 = 18-24 … 13 = 80+) | integer, years | 18-120 | S | **Profile** (date of birth) | ✅ |
| 2 | Sex (`sex`) | `Sex`: 0 female, 1 male | male/female | - | S | **Profile** | ✅ |
| 3 | Weight (`weight_kg`) | → `BMI` (rounded to integer) | number, kg | 20-350 | H | **Each check** (pre-fill last) | ✅ |
| 4 | Height (`height_cm`) | → `BMI` | number, cm | 90-250 | H | **Profile** | ✅ |
| 5 | Told you have high blood pressure (`high_blood_pressure`) | `HighBP` 0/1 | yes/no | - | S | **History** | ✅ |
| 6 | Told you have high cholesterol (`high_cholesterol`) | `HighChol` 0/1 | yes/no | - | S | **History** | ✅ |
| 7 | Cholesterol checked in the last 5 years (`cholesterol_checked_last_5_years`) | `CholCheck` 0/1 | yes/no | - | S | **History** | ❌ missing |
| 8 | Smoked at least 100 cigarettes in your life (`smoked_100_cigarettes`) | `Smoker` 0/1 | yes/no | - | S | **Lifestyle** | ⚠️ asked as Active/Former/Never (Active, Former → yes; Never → no) |
| 9 | Physically active in the past 30 days, outside your job (`physically_active_last_30_days`) | `PhysActivity` 0/1 | yes/no | - | S | **Lifestyle** | ✅ (wording must say "past 30 days, not counting your job") |
| 10 | Eat fruit 1+ times a day (`eats_fruit_daily`) | `Fruits` 0/1 | yes/no | - | S | **Lifestyle** | ❌ missing |
| 11 | Eat vegetables 1+ times a day (`eats_vegetables_daily`) | `Veggies` 0/1 | yes/no | - | S | **Lifestyle** | ❌ missing |
| 12 | Alcoholic drinks per week (`alcohol_drinks_per_week`) | `HvyAlcoholConsump`: men > 14, women > 7 drinks a week = 1 | number, drinks/week | 0-200 | S | **Lifestyle** | ⚠️ asked as yes/no; the API needs a number |
| 13 | Have any health coverage (`has_health_coverage`) | `AnyHealthcare` 0/1 | yes/no | - | S | **Profile** | ❌ missing |
| 14 | Couldn't see a doctor because of cost, past 12 months (`skipped_doctor_due_to_cost`) | `NoDocbcCost` 0/1 | yes/no | - | S | **Each check** (pre-fill last) | ❌ missing |
| 15 | General health (`general_health`) | `GenHlth` 1 excellent … 5 poor | 5 choices | 1-5 | S | **Each check** | ✅ |
| 16 | Days of poor mental health, past 30 (`poor_mental_health_days`) | `MentHlth` | integer, days | 0-30 | S | **Each check** | ❌ missing |
| 17 | Days of poor physical health, past 30 (`poor_physical_health_days`) | `PhysHlth` | integer, days | 0-30 | S | **Each check** | ❌ missing |
| 18 | Serious difficulty walking or climbing stairs (`difficulty_walking`) | `DiffWalk` 0/1 | yes/no | - | S | **History** | ❌ missing |
| 19 | Education level (`education_level`) | `Education` 1-6 | 6 choices | 1-6 | S | **Profile** | ❌ missing |
| 20 | Income level (`income_level`) | `Income` 1-8 (**USD bands** in BRFSS) | 8 choices | 1-8 | S | **Profile** | ❌ missing |

Current Quick form: 10 of 20 asked (2 with the wrong format). **All 20 can be answered without a clinic.**

⚠️ **Income (#20):** BRFSS bands are US dollars per year (1 = under $10,000 … 8 = $75,000+). Malaysian
users need ringgit bands converted to these codes. That conversion is a decision for U1 (it can't be a
silent guess).

---

## 2. Deep-Check: Heart, full model (10 inputs, `POST /predict/deep/heart`)

| Reading (API field) | Model feature | Type, unit | Valid range | How | Proposed home | In current form? |
|---|---|---|---|---|---|---|
| Age | `age` | years | 18-120 | S | **Profile** | ✅ |
| Sex | `sex` | male/female | - | S | **Profile** | ✅ |
| Chest pain type | `cp` | typical angina / atypical angina / non-anginal / asymptomatic | 4 choices | S (symptom description; a doctor's classification is better) | **Each check** | ✅ |
| Resting blood pressure | `trestbps` | mmHg (systolic) | 60-250 | H / C | **Each check** | ✅ |
| Total cholesterol | `chol` | mg/dL | 80-700 | C | **Each check** | ✅ |
| Fasting blood sugar over 120 mg/dL | `fbs` | yes/no | - | C / H (glucose meter, fasting) | **Each check** | ⚠️ asked as a number (110); the app must convert it to yes/no (> 120) |
| Resting ECG result | `restecg` | normal / ST-T abnormality / LV hypertrophy | 3 choices | C (ECG) | **Each check** | ❌ missing |
| Max heart rate during exercise | `thalch` | bpm | 50-230 | **T** | **Each check** | ✅ |
| Chest pain during exercise | `exang` | yes/no | - | **T** | **Each check** | ❌ missing |
| ST depression (exercise vs rest) | `oldpeak` | mm | -3 to 7 | **T** | **Each check** | ✅ |

⚠️ The current heart form also asks **BMI**, **Major Vessel Number** and **High Blood Pressure?**. **None
of them is a model input.** (Major vessels = `ca`, dropped because 66% of the data was missing.) Remove
them from the form, or keep them only for information.

## 3. Deep-Check: Heart, reduced model (H1, 7 inputs, no stress test)
Same as section 2 **without** the three **T** readings (max heart rate, exercise chest pain, ST depression).
Every remaining reading is **S, H or C**. Shown when the user ticks "I haven't done a stress test" (U4b).
It needs a new endpoint name (e.g. `/predict/deep/heart-reduced`, so the existing contract is unchanged)
once you approve the model at Checkpoint 4.

## 4. Deep-Check: Stroke (10 inputs, `POST /predict/deep/stroke`)

| Reading (API field) | Model feature | Type, unit | Valid range | How | Proposed home | In current form? |
|---|---|---|---|---|---|---|
| Age | `age` | years | 1-120 (app: 18+) | S | **Profile** | ✅ |
| Sex | `gender` | male/female | - | S | **Profile** | ✅ |
| Told you have hypertension | `hypertension` | yes/no | - | S | **History** (same as Quick #5) | ✅ |
| Told you have heart disease | `heart_disease` | yes/no | - | S | **History** | ❌ missing |
| Ever married | `ever_married` | yes/no | - | S | **Profile** | ❌ missing |
| Work type | `work_type` | Private / Self-employed / Govt_job / children / Never_worked | 5 choices | S | **Profile** | ❌ missing |
| Residence type | `Residence_type` | Urban / Rural | 2 choices | S | **Profile** | ❌ missing |
| Average glucose level | `avg_glucose_level` | mg/dL | 40-400 | H / C | **Each check** | ✅ |
| BMI | `bmi` | kg/m² | 10-80 | H (from height + weight) | **calculated** | ✅ (typed; should be calculated) |
| Smoking status | `smoking_status` | never smoked / formerly smoked / smokes / Unknown | 4 choices | S | **Lifestyle** | ⚠️ asked as Never/Former/Current (maps cleanly) |

## 5. Deep-Check: Diabetes (8 inputs, `POST /predict/deep/diabetes`)

| Reading (API field) | Model feature | Type, unit | Valid range | How | Proposed home | In current form? |
|---|---|---|---|---|---|---|
| Age | `age` | years | 1-120 (app: 18+) | S | **Profile** | ✅ |
| Sex | `gender` | male/female | - | S | **Profile** | ✅ |
| Told you have hypertension | `hypertension` | yes/no | - | S | **History** | ✅ |
| Told you have heart disease | `heart_disease` | yes/no | - | S | **History** | ❌ missing |
| Smoking history | `smoking_history` | never / former / current / not current / ever / No Info | 6 choices | S | **Lifestyle** | ⚠️ asked as Never/Former/Current (maps cleanly) |
| BMI | `bmi` | kg/m² | 10-80 | H | **calculated** | ✅ (typed; should be calculated) |
| HbA1c | `HbA1c_level` | % | 3-15 | **C** | **Each check** | ✅ |
| Blood glucose | `blood_glucose_level` | mg/dL | 40-400 | H / C | **Each check** | ✅ |

---

## 6. Unique readings across the whole app

| Reading | Quick | Heart | Heart (reduced) | Stroke | Diabetes | How | Proposed home | Lifestyle check? |
|---|---|---|---|---|---|---|---|---|
| Age | ✅ | ✅ | ✅ | ✅ | ✅ | S | Profile | |
| Sex | ✅ | ✅ | ✅ | ✅ | ✅ | S | Profile | |
| Height | ✅ | | | ✅ (BMI) | ✅ (BMI) | H | Profile | |
| Weight | ✅ | | | ✅ (BMI) | ✅ (BMI) | H | Each check | |
| High BP / hypertension | ✅ | | | ✅ | ✅ | S | History | |
| High cholesterol (told) | ✅ | | | | | S | History | |
| Cholesterol checked in 5 years | ✅ | | | | | S | History | |
| Heart disease (told) | | | | ✅ | ✅ | S | History | |
| Difficulty walking | ✅ | | | | | S | History | |
| Smoking (3 encodings) | ✅ | | | ✅ | ✅ | S | Lifestyle | ✅ |
| Physical activity | ✅ | | | | | S | Lifestyle | ✅ |
| Fruit daily | ✅ | | | | | S | Lifestyle | ✅ |
| Vegetables daily | ✅ | | | | | S | Lifestyle | ✅ |
| Alcohol drinks per week | ✅ | | | | | S | Lifestyle | ✅ |
| Health coverage | ✅ | | | | | S | Profile | |
| Education | ✅ | | | | | S | Profile | |
| Income | ✅ | | | | | S | Profile | |
| Ever married | | | | ✅ | | S | Profile | |
| Work type | | | | ✅ | | S | Profile | |
| Residence type | | | | ✅ | | S | Profile | |
| Skipped doctor due to cost | ✅ | | | | | S | Each check | |
| General health | ✅ | | | | | S | Each check | |
| Poor mental-health days | ✅ | | | | | S | Each check | |
| Poor physical-health days | ✅ | | | | | S | Each check | |
| Chest pain type | | ✅ | ✅ | | | S | Each check | |
| Resting blood pressure | | ✅ | ✅ | | | H / C | Each check | |
| Total cholesterol | | ✅ | ✅ | | | C | Each check | |
| Fasting blood sugar > 120 | | ✅ | ✅ | | | C / H | Each check | |
| Resting ECG | | ✅ | ✅ | | | C | Each check | |
| Average / blood glucose | | | | ✅ | ✅ | H / C | Each check | |
| HbA1c | | | | | ✅ | C | Each check | |
| Max heart rate (exercise) | | ✅ | | | | **T** | Each check | |
| Chest pain during exercise | | ✅ | | | | **T** | Each check | |
| ST depression | | ✅ | | | | **T** | Each check | |

**Totals: 34 unique readings.**
- 14 are asked once: 9 Profile + 5 History.
- 5 come from the Lifestyle check.
- The remaining 15 are asked per check.
- Only **3 need a hospital (T)**, all in the full heart model; the reduced model removes them.

## 7. Effect on typing (the goal)

| Screen | Now (API needs) | With Profile + History + Lifestyle pre-filled |
|---|---|---|
| Quick Prediction | 20 | **5**: weight, general health, mental-health days, physical-health days, skipped doctor due to cost (weight pre-filled with the last value) |
| Heart (full / reduced) | 10 / 7 | **8 / 5** (age and sex from Profile) |
| Stroke | 10 | **2**: glucose and weight (everything else pre-filled; BMI calculated) |
| Diabetes | 8 | **3**: HbA1c, glucose, weight |

## 8. Decisions at CHECKPOINT 5 (approved 2026-10-29)
1. **Homes approved exactly as proposed:** Profile = age (date of birth), sex, height, education,
   income, health coverage, ever married, work type, residence type. History = high BP, high
   cholesterol, cholesterol check, heart disease, difficulty walking. Lifestyle = smoking, physical
   activity, fruit, vegetables, alcohol. Each check = everything else.
2. **Income:** the user enters monthly household income in RM; the app converts it to the BRFSS band by
   **percentile matching** (keeps the user's relative position), using DOSM HIES 2022 percentiles. BRFSS
   cumulative shares per band (from the training data): 3.9, 8.5, 14.8, 22.8, 33.0, 47.3, 64.4, 100%.
   You supply the DOSM ringgit thresholds.
3. **Heart:** tapping Deep Check asks *"Have you done an exercise stress test recently?"*. Yes = full
   form (10 readings), No = reduced form (7 readings). Option (a): the reduced form still needs a routine
   clinic check (ECG, cholesterol, fasting blood sugar). BMI, Major Vessel Number and High Blood
   Pressure? are removed from the heart form; Resting ECG and Chest pain during exercise are added.
4. **BMI is always calculated** from height (Profile) and weight (each check), never typed.

### Change 2026-11-04
Reading 1 (age) is now a **date of birth** asked **only at Create Account**, together with sex (2) and
the contact number; My details asks readings 3-9. Age is calculated from the date of birth on the
day of each check.
