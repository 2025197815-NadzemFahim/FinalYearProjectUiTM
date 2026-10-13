"""FastAPI backend: loads the trained models and serves predictions.

Run from the repo root with the venv active:
    uvicorn backend.app.main:app --reload
Then open http://127.0.0.1:8000/docs to try every endpoint in the browser.

Set MODEL_SUFFIX to load dev models, e.g. MODEL_SUFFIX=_dev900.
"""
import os
from contextlib import asynccontextmanager

import joblib
import pandas as pd
from fastapi import FastAPI, HTTPException

from backend.app.conversion import quick_to_brfss
from backend.app.schemas import DiabetesInput, HeartInput, QuickPredictionInput, StrokeInput
from ml import config
from ml.data import prepare_features

SUFFIX = os.getenv("MODEL_SUFFIX", "")
# App-facing disease name for each Model 1 output, in the order the model was trained
LAYER1_NAMES = {"Diabetes_012": "diabetes", "HeartDiseaseorAttack": "heart_disease", "Stroke": "stroke"}
DISCLAIMER = ("This is a screening estimate, not a medical diagnosis. "
              "Please consult a healthcare professional.")
MODELS: dict = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Load every model once at startup, not on every request
    names = ["layer1_general"] + [f"layer2_{n}" for n in config.LAYER2]
    for name in names:
        path = config.MODELS / f"{name}{SUFFIX}.joblib"
        if path.exists():
            MODELS[name] = joblib.load(path)
    print(f"Loaded models: {sorted(MODELS)}")
    yield
    MODELS.clear()


app = FastAPI(title="Chronic Disease Early Prediction API", lifespan=lifespan)


def _model(name: str):
    if name not in MODELS:
        raise HTTPException(503, f"Model '{name}' is not trained yet.")
    return MODELS[name]


@app.get("/health")
def health():
    return {"status": "ok", "models_loaded": sorted(MODELS)}


# ------------------------------------------------------------ Layer 1
@app.post("/predict/quick")
def predict_quick(body: QuickPredictionInput):
    """General screening across all three diseases (FR-06).

    The result is not stored (report section 3.5.1). Diseases are returned
    sorted from highest to lowest risk (report section 1.6).
    """
    X = prepare_features(pd.DataFrame([quick_to_brfss(body)]), config.BRFSS_FEATURES, [])
    # Model 1 is one multi-output model: a single call returns one
    # probability array per disease, in the order of config.BRFSS_TARGETS
    outputs = _model("layer1_general").predict_proba(X)
    results = []
    for target, proba in zip(config.BRFSS_TARGETS, outputs):
        proba = proba[0]
        # Diabetes_012 is 3-class (0 none, 1 prediabetes, 2 diabetes):
        # risk = probability of anything other than "none"
        risk = float(1 - proba[0])
        item = {"disease": LAYER1_NAMES[target], "risk_percent": round(risk * 100, 1)}
        if target == "Diabetes_012":
            item["breakdown"] = {"prediabetes": round(float(proba[1]) * 100, 1),
                                 "diabetes": round(float(proba[2]) * 100, 1)}
        results.append(item)
    results.sort(key=lambda r: r["risk_percent"], reverse=True)
    return {"results": results, "disclaimer": DISCLAIMER}


# ------------------------------------------------------------ Layer 2
def _deep(name: str, row: dict, notes: list):
    spec = config.LAYER2[name]
    X = prepare_features(pd.DataFrame([row]), spec["numeric"], spec["categorical"])
    risk = float(_model(f"layer2_{name}").predict_proba(X)[0, 1])
    # TODO: persist to Firestore (users/{uid}/deepCheckResults) once the
    #       Firebase project exists - needs firebase-admin + serviceAccountKey.json
    return {"disease": name, "risk_percent": round(risk * 100, 1),
            "explanation": notes or ["No individual input is outside its usual range."],
            "disclaimer": DISCLAIMER}


@app.post("/predict/deep/heart")
def predict_heart(b: HeartInput):
    row = {"age": b.age, "sex": b.sex.capitalize(), "cp": b.chest_pain_type,
           "trestbps": b.resting_bp, "chol": b.cholesterol,
           "fbs": b.fasting_blood_sugar_over_120, "restecg": b.resting_ecg,
           "thalch": b.max_heart_rate, "exang": b.exercise_induced_angina,
           "oldpeak": b.st_depression}
    notes = []
    if b.resting_bp >= 140: notes.append("Resting blood pressure is in the hypertensive range (>= 140 mmHg).")
    if b.cholesterol >= 240: notes.append("Total cholesterol is high (>= 240 mg/dL).")
    if b.exercise_induced_angina: notes.append("Chest pain during exercise is a recognised warning sign.")
    if b.st_depression >= 2: notes.append("ST depression of 2 or more is associated with higher risk.")
    return _deep("heart", row, notes)


@app.post("/predict/deep/stroke")
def predict_stroke(b: StrokeInput):
    row = {"gender": b.sex.capitalize(), "age": b.age, "hypertension": b.hypertension,
           "heart_disease": b.heart_disease, "ever_married": "Yes" if b.ever_married else "No",
           "work_type": b.work_type, "Residence_type": b.residence_type,
           "avg_glucose_level": b.avg_glucose_level, "bmi": b.bmi,
           "smoking_status": b.smoking_status}
    notes = []
    if b.hypertension: notes.append("Hypertension is the strongest modifiable stroke risk factor.")
    if b.avg_glucose_level >= 140: notes.append("Average glucose level is elevated (>= 140 mg/dL).")
    if b.bmi >= 30: notes.append("BMI is in the obese range (>= 30).")
    if b.smoking_status == "smokes": notes.append("Current smoking increases stroke risk.")
    return _deep("stroke", row, notes)


@app.post("/predict/deep/diabetes")
def predict_diabetes(b: DiabetesInput):
    row = {"gender": b.sex.capitalize(), "age": b.age, "hypertension": b.hypertension,
           "heart_disease": b.heart_disease, "smoking_history": b.smoking_history,
           "bmi": b.bmi, "HbA1c_level": b.hba1c_level,
           "blood_glucose_level": b.blood_glucose_level}
    notes = []
    if b.hba1c_level >= 6.5: notes.append("HbA1c is in the diabetic range (>= 6.5%).")
    elif b.hba1c_level >= 5.7: notes.append("HbA1c is in the prediabetic range (5.7-6.4%).")
    if b.blood_glucose_level >= 200: notes.append("Blood glucose is very high (>= 200 mg/dL).")
    if b.bmi >= 30: notes.append("BMI is in the obese range (>= 30).")
    return _deep("diabetes", row, notes)
