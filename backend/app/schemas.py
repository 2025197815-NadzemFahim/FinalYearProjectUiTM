"""Request bodies. Pydantic rejects out-of-range values with a 422 error,
which covers FR-04 (validate user input) on the server side."""
from typing import Literal

from pydantic import BaseModel, Field

Sex = Literal["male", "female"]


class QuickPredictionInput(BaseModel):
    age: int = Field(ge=18, le=120)
    sex: Sex
    weight_kg: float = Field(gt=20, lt=350)
    height_cm: float = Field(gt=90, lt=250)
    high_blood_pressure: bool
    high_cholesterol: bool
    cholesterol_checked_last_5_years: bool
    smoked_100_cigarettes: bool = Field(description="At least 100 cigarettes in your life")
    physically_active_last_30_days: bool
    eats_fruit_daily: bool
    eats_vegetables_daily: bool
    alcohol_drinks_per_week: float = Field(ge=0, le=200)
    has_health_coverage: bool
    skipped_doctor_due_to_cost: bool
    general_health: int = Field(ge=1, le=5, description="1 excellent ... 5 poor")
    poor_mental_health_days: int = Field(ge=0, le=30)
    poor_physical_health_days: int = Field(ge=0, le=30)
    difficulty_walking: bool
    education_level: int = Field(ge=1, le=6)
    income_level: int = Field(ge=1, le=8)


class HeartInput(BaseModel):
    age: int = Field(ge=18, le=120)
    sex: Sex
    chest_pain_type: Literal["typical angina", "atypical angina", "non-anginal", "asymptomatic"]
    resting_bp: float = Field(gt=60, lt=250, description="mmHg")
    cholesterol: float = Field(gt=80, lt=700, description="mg/dL")
    fasting_blood_sugar_over_120: bool
    resting_ecg: Literal["normal", "st-t abnormality", "lv hypertrophy"]
    max_heart_rate: float = Field(gt=50, lt=230)
    exercise_induced_angina: bool
    st_depression: float = Field(ge=-3, le=7)


class StrokeInput(BaseModel):
    age: int = Field(ge=1, le=120)
    sex: Sex
    hypertension: bool
    heart_disease: bool
    ever_married: bool
    work_type: Literal["Private", "Self-employed", "Govt_job", "children", "Never_worked"]
    residence_type: Literal["Urban", "Rural"]
    avg_glucose_level: float = Field(gt=40, lt=400, description="mg/dL")
    bmi: float = Field(gt=10, lt=80)
    smoking_status: Literal["never smoked", "formerly smoked", "smokes", "Unknown"]


class DiabetesInput(BaseModel):
    age: int = Field(ge=1, le=120)
    sex: Sex
    hypertension: bool
    heart_disease: bool
    smoking_history: Literal["never", "former", "current", "not current", "ever", "No Info"]
    bmi: float = Field(gt=10, lt=80)
    hba1c_level: float = Field(gt=3, lt=15, description="%")
    blood_glucose_level: float = Field(gt=40, lt=400, description="mg/dL")
