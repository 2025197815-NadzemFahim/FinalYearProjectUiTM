"""End-to-end API test. Run from the repo root:
    python -m backend.tests.test_api            (uses MODEL_SUFFIX, default _dev900)
"""
import os
import typing

os.environ.setdefault("MODEL_SUFFIX", "_dev900")

from fastapi.testclient import TestClient  # noqa: E402

from backend.app import schemas  # noqa: E402
from backend.app.main import MODELS, app  # noqa: E402

QUICK = dict(age=52, sex="male", weight_kg=88, height_cm=170, high_blood_pressure=True,
             high_cholesterol=True, cholesterol_checked_last_5_years=True,
             smoked_100_cigarettes=True, physically_active_last_30_days=False,
             eats_fruit_daily=False, eats_vegetables_daily=True, alcohol_drinks_per_week=3,
             has_health_coverage=True, skipped_doctor_due_to_cost=False, general_health=4,
             poor_mental_health_days=5, poor_physical_health_days=10, difficulty_walking=False,
             education_level=4, income_level=5)
HEART = dict(age=58, sex="male", chest_pain_type="asymptomatic", resting_bp=150, cholesterol=260,
             fasting_blood_sugar_over_120=True, resting_ecg="lv hypertrophy", max_heart_rate=120,
             exercise_induced_angina=True, st_depression=2.3)
STROKE = dict(age=67, sex="female", hypertension=True, heart_disease=False, ever_married=True,
              work_type="Private", residence_type="Urban", avg_glucose_level=180, bmi=31,
              smoking_status="formerly smoked")
DIABETES = dict(age=55, sex="female", hypertension=True, heart_disease=False,
                smoking_history="former", bmi=32, hba1c_level=6.8, blood_glucose_level=180)


def check_categories_match_models():
    """Every allowed API value must be a category the model saw in training.
    (The encoder silently ignores unseen values, so a typo would go unnoticed.)"""
    api_field = {"heart": {"cp": "chest_pain_type", "restecg": "resting_ecg"},
                 "stroke": {"work_type": "work_type", "Residence_type": "residence_type",
                            "smoking_status": "smoking_status"},
                 "diabetes": {"smoking_history": "smoking_history"}}
    schema = {"heart": schemas.HeartInput, "stroke": schemas.StrokeInput,
              "diabetes": schemas.DiabetesInput}
    for name, mapping in api_field.items():
        m = MODELS[f"layer2_{name}"]
        enc = m.preprocessor_.named_transformers_["cat"].named_steps["onehot"]
        learned = dict(zip(m.categorical, (set(c) for c in enc.categories_)))
        for feat, field in mapping.items():
            allowed = set(typing.get_args(schema[name].model_fields[field].annotation))
            assert allowed <= learned[feat], f"{name}.{field}: {allowed - learned[feat]} unseen"
    print("  OK  API enum values all match trained categories")


def main():
    with TestClient(app) as c:
        h = c.get("/health").json()
        assert h["models_loaded"] == ["layer1_general", "layer2_diabetes", "layer2_heart", "layer2_stroke"], h
        print(f"  OK  /health -> {len(h['models_loaded'])} models")
        check_categories_match_models()

        r = c.post("/predict/quick", json=QUICK)
        assert r.status_code == 200, r.text
        res = r.json()["results"]
        assert [x["risk_percent"] for x in res] == sorted((x["risk_percent"] for x in res), reverse=True)
        print("  OK  /predict/quick ->", [(x["disease"], x["risk_percent"]) for x in res])

        for path, body in [("heart", HEART), ("stroke", STROKE), ("diabetes", DIABETES)]:
            r = c.post(f"/predict/deep/{path}", json=body)
            assert r.status_code == 200, r.text
            j = r.json()
            assert 0 <= j["risk_percent"] <= 100
            print(f"  OK  /predict/deep/{path} -> {j['risk_percent']}% | {len(j['explanation'])} note(s)")

        bad = dict(QUICK, age=10)
        assert c.post("/predict/quick", json=bad).status_code == 422
        print("  OK  invalid input (age=10) rejected with 422")
    print("All API checks passed.")


if __name__ == "__main__":
    main()
