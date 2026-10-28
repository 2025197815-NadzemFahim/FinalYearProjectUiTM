
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
PROCESSED = ROOT / "data" / "processed"
MODELS = ROOT / "ml" / "models"
REPORTS = ROOT / "ml" / "reports"

RANDOM_STATE = 42
TEST_SIZE = 0.20          # 80:20 split (report section 3.4)
CV_FOLDS = 5              # out-of-fold predictions for the meta-learner

# --------------------------------------------------------------------------
# Layer 1: general screening model (BRFSS 2015)
# --------------------------------------------------------------------------
BRFSS_FILE = RAW / "brfss" / "diabetes_012_health_indicators_BRFSS2015.csv"
BRFSS_TARGETS = ["Diabetes_012", "HeartDiseaseorAttack", "Stroke"]

BRFSS_FEATURES = [
    "HighBP", "HighChol", "CholCheck", "BMI", "Smoker", "PhysActivity",
    "Fruits", "Veggies", "HvyAlcoholConsump", "AnyHealthcare", "NoDocbcCost",
    "GenHlth", "MentHlth", "PhysHlth", "DiffWalk", "Sex", "Age",
    "Education", "Income",
]

# --------------------------------------------------------------------------
# Layer 2: disease-specific deep-check models
# --------------------------------------------------------------------------
LAYER2 = {
    "heart": {
        "file": RAW / "layer2" / "heart_disease_uci.csv",
        "target": "target",              # derived: num > 0
        "numeric": ["age", "trestbps", "chol", "thalch", "oldpeak"],
        "categorical": ["sex", "cp", "fbs", "restecg", "exang"],
        "resample": False,               # ~55/45 split, near-balanced
    },
    "stroke": {
        "file": RAW / "layer2" / "healthcare-dataset-stroke-data.csv",
        "target": "stroke",
        "numeric": ["age", "avg_glucose_level", "bmi"],
        "categorical": ["gender", "hypertension", "heart_disease", "ever_married",
                        "work_type", "Residence_type", "smoking_status"],
        "resample": True,                # 4.9% positive
    },
    "diabetes": {
        "file": RAW / "layer2" / "diabetes_prediction_dataset.csv",
        "target": "diabetes",
        "numeric": ["age", "bmi", "HbA1c_level", "blood_glucose_level"],
        "categorical": ["gender", "hypertension", "heart_disease", "smoking_history"],
        "resample": True,                # 8.5% positive
    },
}

# Model roles per disease. "full" = the LAYER2 reading list above.
# Other roles use fewer readings from the SAME dataset, e.g. the reduced heart
# model for users without an exercise stress test (no thalch, exang, oldpeak).
LAYER2_ROLES = {
    "heart": {
        "reduced": {"numeric": ["age", "trestbps", "chol"],
                    "categorical": ["sex", "cp", "fbs", "restecg"]},
    },
}

# Dataset versions: the registry records which data every model learned from
DATASET_VERSIONS = {"heart": "uci-v1", "stroke": "kaggle-v1", "diabetes": "kaggle-v1"}

# --------------------------------------------------------------------------
# Rebalancing
# --------------------------------------------------------------------------
MINORITY_RATIO = 0.3

# --------------------------------------------------------------------------
# Base learners and meta-learner (report section 2.4: XGB + RF + KNN -> LGBM)
# --------------------------------------------------------------------------
XGB_PARAMS = dict(n_estimators=400, max_depth=6, learning_rate=0.05,
                  subsample=0.8, colsample_bytree=0.8, tree_method="hist",
                  n_jobs=-1, random_state=RANDOM_STATE, verbosity=0)
RF_PARAMS = dict(n_estimators=300, min_samples_leaf=2, n_jobs=-1,
                 random_state=RANDOM_STATE)
KNN_PARAMS = dict(n_neighbors=15, weights="distance", n_jobs=-1)
# Shallow meta-learner: it only sees a handful of probability columns,
# so a deep model would overfit the out-of-fold predictions.
META_PARAMS = dict(n_estimators=200, learning_rate=0.05, num_leaves=15,
                   max_depth=4, min_child_samples=50, random_state=RANDOM_STATE,
                   verbose=-1)
# Monotone meta-learner (binary targets only): a higher P(disease) from any
# base learner may never LOWER the ensemble's risk. Keeps the meta-learner
# from scrambling the risk ordering on small data (stroke has ~160 cases per
# training fold). Not used for 3-class Diabetes_012, where a higher P(class 1)
# should lower the other classes, so one "increasing" rule would be wrong.
META_MONOTONE = True

# Decision threshold, chosen from training out-of-fold predictions only
# "f1"     -> threshold with the best F1 (balance of precision and recall)
# "recall" -> highest precision while keeping recall >= MIN_RECALL (screening focus)
THRESHOLD_MODE = "f1"
MIN_RECALL = 0.85

# Bootstrap confidence intervals: number of test-set resamples
N_BOOTSTRAP = 1000
