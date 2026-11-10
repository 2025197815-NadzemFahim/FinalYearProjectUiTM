"""Database tests against the local Firebase emulators.

Needs the emulators running (see docs/DATABASE.md), then from the repo root:
    python -m backend.tests.test_db

Checks two things:
 1. Security rules - talks to Firestore exactly like the Flutter app would
    (REST API + the user's ID token), so the rules are really enforced.
 2. API + database - deep-check results are saved for signed-in users only,
    and each user only ever sees their own history.
"""
import os
import uuid
from datetime import datetime, timedelta, timezone

os.environ.setdefault("FIRESTORE_EMULATOR_HOST", "127.0.0.1:8080")
os.environ.setdefault("FIREBASE_AUTH_EMULATOR_HOST", "127.0.0.1:9099")
os.environ.setdefault("MODEL_SUFFIX", "_dev900")

import httpx                                          # noqa: E402
from fastapi.testclient import TestClient             # noqa: E402
from firebase_admin import auth                       # noqa: E402

from backend.app import db                            # noqa: E402
from backend.app.main import app                      # noqa: E402
from backend.tests.test_api import HEART              # noqa: E402

FS = f"http://{os.environ['FIRESTORE_EMULATOR_HOST']}/v1/projects/{db.PROJECT_ID}/databases/(default)/documents"
AUTH = f"http://{os.environ['FIREBASE_AUTH_EMULATOR_HOST']}/identitytoolkit.googleapis.com/v1"
PASSWORD = "password123"
results = []


def check(cond, msg):
    results.append(bool(cond))
    print(("  PASS  " if cond else "  FAIL  ") + msg)


def new_user():
    """Auth user + ID token, like a freshly registered app user."""
    email = f"test-{uuid.uuid4().hex[:8]}@test.com"
    uid = auth.create_user(email=email, password=PASSWORD).uid
    r = httpx.post(f"{AUTH}/accounts:signInWithPassword?key=demo-api-key",
                   json={"email": email, "password": PASSWORD, "returnSecureToken": True})
    return uid, email, r.json()["idToken"]


def fs_value(v):
    """Python value -> the typed value Firestore's REST API expects (what the app's SDK sends)."""
    if isinstance(v, bool):
        return {"booleanValue": v}
    if isinstance(v, int):
        return {"integerValue": str(v)}
    if isinstance(v, float):
        return {"doubleValue": v}
    if isinstance(v, str):
        return {"stringValue": v}
    if isinstance(v, datetime):
        return {"timestampValue": v.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}
    if isinstance(v, dict):
        return {"mapValue": {"fields": {k: fs_value(x) for k, x in v.items()}}}
    raise TypeError(f"no Firestore type for {v!r}")


def _commit(uid, token, fields, *, create):
    """One write to users/{uid} with the user's token, so the security rules apply."""
    name = f"projects/{db.PROJECT_ID}/databases/(default)/documents/users/{uid}"
    write = {"update": {"name": name, "fields": {k: fs_value(v) for k, v in fields.items()}}}
    if create:   # like Create Account: new document + the server's clock
        write["updateTransforms"] = [{"fieldPath": "userCreate_at", "setToServerValue": "REQUEST_TIME"}]
        write["currentDocument"] = {"exists": False}
    else:        # like a Save in the app: replace only these fields
        write["updateMask"] = {"fieldPaths": list(fields)}
        write["currentDocument"] = {"exists": True}
    return httpx.post(f"{FS}:commit", json={"writes": [write]},
                      headers={"Authorization": f"Bearer {token}"}).status_code


def rest_create_profile(uid, token, email, age, sex="male"):
    """Create users/{uid} the way the Flutter app's Create Account does."""
    born = datetime.now(timezone.utc) - timedelta(days=round(age * 365.25))
    return _commit(uid, token, {"userName": "Test User", "userEmail": email, "userSex": sex,
                                "dateOfBirth": born, "contactNumber": "0123456789"}, create=True)


def rest_update(uid, token, fields):
    """Save some fields the way the app's My details / Medical history / Lifestyle screens do."""
    return _commit(uid, token, fields, create=False)


# Valid answers, in the app's layout (mobile/lib/services/firestore_maps.dart)
MY_DETAILS = {"heightCm": 170.5, "education": "spm", "incomeMonthlyRm": 6500,
              "healthCoverage": True, "everMarried": True, "workType": "government",
              "residence": "urban"}
HISTORY = {"highBloodPressure": True, "highCholesterol": False, "cholesterolChecked5y": True,
           "heartDisease": False, "difficultyWalking": False, "updatedAt": datetime.now(timezone.utc)}
LIFESTYLE = {"smoked100": True, "smokesNow": False, "activity": "oneTwoWeekly",
             "fruit": "onceDaily", "vegetables": "rarely", "drinksAlcohol": False,
             "updatedAt": datetime.now(timezone.utc)}


def rest_get(path, token):
    return httpx.get(f"{FS}/{path}", headers={"Authorization": f"Bearer {token}"}).status_code


def test_rules(a, b):
    print("\n[Security rules - as the Flutter app]")
    (ua, ea, ta), (ub, eb, tb) = a, b
    check(rest_create_profile(ua, ta, ea, age=10) == 403, "profile with age 10 is rejected (must be 18-120)")
    check(rest_create_profile(ua, ta, "someone@else.com", age=30) == 403,
          "profile with an email that isn't the signed-in user's is rejected")
    check(rest_create_profile(ua, ta, ea, age=30) == 200, "valid profile creation is allowed")
    check(rest_create_profile(ub, tb, eb, age=40, sex="female") == 200, "second user can create theirs")
    check(rest_create_profile(ub, ta, eb, age=40) == 403, "user A cannot create user B's profile")
    check(rest_get(f"users/{ua}", ta) == 200, "user A can read their own profile")

    # Saving answers from the app (FR-05)
    check(rest_update(ua, ta, {"profile": MY_DETAILS, "history": HISTORY,
                               "lifestyle": LIFESTYLE, "lastWeightKg": 70.5}) == 200,
          "saving My details, Medical history, Lifestyle and weight is allowed")
    check(rest_update(ua, ta, {"profile": {**MY_DETAILS, "heightCm": 999}}) == 403,
          "a height of 999 cm is rejected (must be 90-250)")
    check(rest_update(ua, ta, {"lifestyle": {**LIFESTYLE, "drinksPerWeek": 5}}) == 403,
          "drinks per week for someone who doesn't drink is rejected")
    check(rest_update(ua, ta, {"lifestyle": {**LIFESTYLE, "drinksAlcohol": True,
                                             "drinksPerWeek": 5}}) == 200,
          "drinks per week for someone who drinks is allowed")
    check(rest_update(ua, ta, {"isAdmin": True}) == 403, "an unknown extra field is rejected")
    check(rest_update(ua, ta, {"userEmail": "other@test.com"}) == 403, "the email cannot be changed")
    check(rest_get(f"users/{ub}", ta) == 403, "user A cannot read user B's profile")
    fake = {"fields": {"risk_percentage": {"doubleValue": 1.0}}}
    r = httpx.post(f"{FS}/users/{ua}/deepCheckResults", json=fake,
                   headers={"Authorization": f"Bearer {ta}"})
    check(r.status_code == 403, "app cannot write its own deep-check result (no faking a risk %)")
    no_token = httpx.get(f"{FS}/users/{ua}").status_code
    check(no_token == 403, f"reading a profile with no token is denied by the rules ({no_token})")
    bad = rest_get(f"users/{ua}", "not-a-real-token")
    check(bad in (400, 401, 403), f"a malformed token is rejected before any data is returned ({bad})")


def test_api(a, b):
    print("\n[API + database]")
    (ua, _, ta), (ub, _, tb) = a, b
    with TestClient(app) as c:
        check(c.get("/health").json()["database"] is True, "/health reports the database connected")

        r = c.post("/predict/deep/heart", json=HEART)
        check(r.status_code == 200 and r.json()["result_id"] is None,
              "anonymous deep check works but is NOT saved")

        r = c.post("/predict/deep/heart", json=HEART, headers={"Authorization": f"Bearer {ta}"})
        rid = r.json().get("result_id")
        check(r.status_code == 200 and rid, f"signed-in deep check is saved (result_id {rid})")

        saved = db.get_deep_check(ua, rid)
        check(saved and saved["diseaseInput"]["resting_bp"] == HEART["resting_bp"]
              and saved["userID"] == ua and saved["diseaseType"] == "heart",
              "stored record has the user, disease type and the exact inputs")

        h = c.get("/history", headers={"Authorization": f"Bearer {ta}"}).json()["results"]
        check(len(h) == 1 and h[0]["resultID"] == rid, "user A's history contains exactly that result")
        check(c.get("/history", headers={"Authorization": f"Bearer {tb}"}).json()["results"] == [],
              "user B's history is empty (no leaking between users)")
        check(c.get(f"/history/{rid}", headers={"Authorization": f"Bearer {tb}"}).status_code == 404,
              "user B cannot open user A's result by its id")
        check(c.get("/history").status_code == 401, "/history without a token -> 401")
        check(c.post("/predict/deep/heart", json=HEART,
                     headers={"Authorization": "Bearer garbage"}).status_code == 401,
              "an invalid token -> 401")
        check(rest_get(f"users/{ua}/deepCheckResults/{rid}", ta) == 200,
              "the app can read that saved result directly from Firestore")


def main():
    db.init_db()
    a, b = new_user(), new_user()
    try:
        test_rules(a, b)
        test_api(a, b)
    finally:
        for uid, _, _ in (a, b):
            db.delete_user_data(uid)
            auth.delete_user(uid)
    print(f"\n{sum(results)}/{len(results)} checks passed -> "
          + ("ALL CHECKS PASSED" if all(results) else "SOME CHECKS FAILED"))
    raise SystemExit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
