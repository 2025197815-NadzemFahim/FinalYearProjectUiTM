"""Clinical Input Conversion layer (FR-07).

The app collects real-world values (age in years, weight in kg, ...) but the
BRFSS model was trained on survey codes (age band 1-13, integer BMI, ...).
These functions translate one into the other. Keep them in sync with the
codebook: https://www.cdc.gov/brfss/annual_data/annual_2015.html
"""

# _AGEG5YR: 1 = 18-24, 2 = 25-29, then 5-year bands, 13 = 80+
_AGE_BANDS = [(24, 1), (29, 2), (34, 3), (39, 4), (44, 5), (49, 6), (54, 7),
              (59, 8), (64, 9), (69, 10), (74, 11), (79, 12)]


def age_to_brfss(age_years: int) -> int:
    for upper, code in _AGE_BANDS:
        if age_years <= upper:
            return code
    return 13


def bmi(weight_kg: float, height_cm: float) -> float:
    return weight_kg / (height_cm / 100) ** 2


def heavy_drinker(drinks_per_week: float, sex: str) -> int:
    """BRFSS definition: men > 14 drinks/week, women > 7 drinks/week."""
    return int(drinks_per_week > (14 if sex == "male" else 7))


def quick_to_brfss(q) -> dict:
    """Map a QuickPredictionInput to the 19 BRFSS feature columns."""
    return {
        "HighBP": int(q.high_blood_pressure),
        "HighChol": int(q.high_cholesterol),
        "CholCheck": int(q.cholesterol_checked_last_5_years),
        "BMI": round(bmi(q.weight_kg, q.height_cm)),   # BRFSS stores BMI as an integer
        "Smoker": int(q.smoked_100_cigarettes),
        "PhysActivity": int(q.physically_active_last_30_days),
        "Fruits": int(q.eats_fruit_daily),
        "Veggies": int(q.eats_vegetables_daily),
        "HvyAlcoholConsump": heavy_drinker(q.alcohol_drinks_per_week, q.sex),
        "AnyHealthcare": int(q.has_health_coverage),
        "NoDocbcCost": int(q.skipped_doctor_due_to_cost),
        "GenHlth": q.general_health,                   # 1 excellent ... 5 poor
        "MentHlth": q.poor_mental_health_days,         # days in the past 30
        "PhysHlth": q.poor_physical_health_days,
        "DiffWalk": int(q.difficulty_walking),
        "Sex": 1 if q.sex == "male" else 0,            # BRFSS: 0 female, 1 male
        "Age": age_to_brfss(q.age),
        "Education": q.education_level,                # 1-6
        "Income": q.income_level,                      # 1-8 (USD bands in BRFSS)
    }
