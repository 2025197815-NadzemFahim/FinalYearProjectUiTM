"""Firestore data-access layer (the database in the ERD, Figure 3.14).

Every read/write the backend does to Firestore goes through this file, so the
data layout lives in one place. Layout (documented in docs/DATABASE.md):

    users/{userID}                               ERD: User
        userName, userEmail, userSex, userCreate_at, dateOfBirth, contactNumber
        profile {..}, history {..}, lifestyle {..}, lastWeightKg   (saved by the app)
    users/{userID}/deepCheckResults/{resultID}   ERD: DeepCheckResult
        resultID, userID, diseaseType, risk_percentage, explanation_text,
        created_at, modelName,
        diseaseInput { inputID, ...fields }      ERD: DiseaseInput + Heart/Stroke/DiabetesInput

Connection is chosen by environment variables:
    FIRESTORE_EMULATOR_HOST=127.0.0.1:8080   -> local emulator, no credentials needed
    FIREBASE_CREDENTIALS=path/to/serviceAccountKey.json -> real Firebase project
    neither                                  -> database disabled; predictions still work,
                                                deep-check results just aren't saved
"""
import os
import sys
import uuid
from datetime import date, datetime, timedelta, timezone

import firebase_admin
import google.auth.credentials
from firebase_admin import credentials, firestore

PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "demo-fyp-chronic")
USERS = "users"
RESULTS = "deepCheckResults"
DISEASE_TYPES = ("heart", "stroke", "diabetes")

_db = None


class _EmulatorCredential(credentials.Base):
    """The Admin SDK insists on a credential; the emulator accepts an anonymous one."""

    def get_credential(self):
        return google.auth.credentials.AnonymousCredentials()


def init_db() -> bool:
    """Connect once at startup. Returns True if a database is available."""
    global _db
    if _db is not None:
        return True
    if os.getenv("FIRESTORE_EMULATOR_HOST"):
        cred, mode = _EmulatorCredential(), f"emulator at {os.environ['FIRESTORE_EMULATOR_HOST']}"
    elif os.getenv("FIREBASE_CREDENTIALS"):
        cred, mode = credentials.Certificate(os.environ["FIREBASE_CREDENTIALS"]), "Firebase project"
    else:
        print("Database: disabled (set FIRESTORE_EMULATOR_HOST or FIREBASE_CREDENTIALS)", file=sys.stderr)
        return False
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred, {"projectId": PROJECT_ID})
    _db = firestore.client()
    # stderr, so tools that print data (e.g. db_tool token) stay clean
    print(f"Database: connected to {mode} (project {PROJECT_ID})", file=sys.stderr)
    return True


def enabled() -> bool:
    return _db is not None


def _require():
    if _db is None:
        raise RuntimeError("Database is not connected - call init_db() first.")
    return _db


# ---------------------------------------------------------------- User
MALAYSIA = timezone(timedelta(hours=8))


def create_user_profile(uid, user_name, user_email, date_of_birth: date, user_sex,
                        contact_number, details: dict | None = None) -> dict:
    """Create users/{uid}. Normally the Flutter app does this itself at Create
    Account (allowed by the security rules); this admin version is for seeding,
    tests and tools.

    The date of birth is stored as midnight Malaysian time, the same as the app
    writes it from a phone in Malaysia. `details` optionally adds the answer maps
    (profile / history / lifestyle / lastWeightKg) in the app's layout
    (mobile/lib/services/firestore_maps.dart)."""
    dob = datetime(date_of_birth.year, date_of_birth.month, date_of_birth.day, tzinfo=MALAYSIA)
    doc = {"userName": user_name, "userEmail": user_email, "userSex": user_sex,
           "dateOfBirth": dob, "contactNumber": contact_number,
           "userCreate_at": firestore.SERVER_TIMESTAMP, **(details or {})}
    _require().collection(USERS).document(uid).set(doc)
    return get_user(uid)


def age_from_birth(dob: datetime, today: date | None = None) -> int:
    """Whole years: one less if this year's birthday hasn't come yet (same as the app)."""
    born = dob.astimezone(MALAYSIA).date()
    today = today or datetime.now(MALAYSIA).date()
    return today.year - born.year - ((today.month, today.day) < (born.month, born.day))


def get_user(uid) -> dict | None:
    snap = _require().collection(USERS).document(uid).get()
    return {"userID": snap.id, **snap.to_dict()} if snap.exists else None


def list_users(limit=100) -> list[dict]:
    return [{"userID": s.id, **s.to_dict()}
            for s in _require().collection(USERS).limit(limit).stream()]


# ---------------------------------------------------------------- DeepCheckResult
def save_deep_check(uid, disease_type, disease_input: dict, risk_percentage,
                    explanation: list, model_name) -> str:
    """Store one deep-check prediction (FR-08) with the exact inputs the model saw.

    DeepCheckResult and DiseaseInput are 1:1 and always read together, so the
    input is embedded as a map instead of a separate collection - the usual
    Firestore way to model a one-to-one relationship.
    """
    if disease_type not in DISEASE_TYPES:
        raise ValueError(f"diseaseType must be one of {DISEASE_TYPES}")
    ref = _require().collection(USERS).document(uid).collection(RESULTS).document()
    ref.set({
        "resultID": ref.id,
        "userID": uid,
        "diseaseType": disease_type,
        "risk_percentage": float(risk_percentage),
        "explanation_text": list(explanation),
        "created_at": firestore.SERVER_TIMESTAMP,
        "modelName": model_name,
        "diseaseInput": {"inputID": uuid.uuid4().hex, **disease_input},
    })
    return ref.id


def list_deep_checks(uid, disease_type=None, limit=50) -> list[dict]:
    """FR-10 View Prediction History: newest first, optionally one disease only."""
    q = _require().collection(USERS).document(uid).collection(RESULTS)
    if disease_type:
        q = q.where(filter=firestore.FieldFilter("diseaseType", "==", disease_type))
    q = q.order_by("created_at", direction=firestore.Query.DESCENDING).limit(limit)
    return [s.to_dict() for s in q.stream()]


def get_deep_check(uid, result_id) -> dict | None:
    snap = (_require().collection(USERS).document(uid)
            .collection(RESULTS).document(result_id).get())
    return snap.to_dict() if snap.exists else None


def delete_user_data(uid):
    """Remove a user's profile and all their results (tests / reset tools)."""
    db = _require()
    user = db.collection(USERS).document(uid)
    for s in user.collection(RESULTS).stream():
        s.reference.delete()
    user.delete()
