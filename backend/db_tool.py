"""Command-line tool for the database (emulator by default).

Run from the repo root with the venv active and the emulators running:

    python -m backend.db_tool seed                 # demo users + sample history
    python -m backend.db_tool users                # list user profiles
    python -m backend.db_tool history ali@demo.com # one user's deep-check results
    python -m backend.db_tool token ali@demo.com   # ID token to test the API in /docs
    python -m backend.db_tool reset                # delete ALL data (emulator only)

Demo accounts created by `seed` all use the password  password123
"""
import argparse
import os
import sys

# Default to the local emulators so this tool can never touch a real
# project by accident. Destructive commands refuse to run without them.
os.environ.setdefault("FIRESTORE_EMULATOR_HOST", "127.0.0.1:8080")
os.environ.setdefault("FIREBASE_AUTH_EMULATOR_HOST", "127.0.0.1:9099")

import httpx                                   # noqa: E402
from firebase_admin import auth                # noqa: E402

from backend.app import db                     # noqa: E402

AUTH_HOST = os.environ["FIREBASE_AUTH_EMULATOR_HOST"]
DEMO_PASSWORD = "password123"

DEMO_USERS = [
    {"email": "ali@demo.com", "name": "Ali Ahmad", "age": 52, "sex": "male"},
    {"email": "siti@demo.com", "name": "Siti Aminah", "age": 61, "sex": "female"},
]
# Sample history, shaped exactly like what the API saves (field names match backend/app/schemas.py)
DEMO_RESULTS = {
    "ali@demo.com": [
        ("heart", 72.4, ["Resting blood pressure is in the hypertensive range (>= 140 mmHg)."],
         dict(age=52, sex="male", chest_pain_type="asymptomatic", resting_bp=150, cholesterol=260,
              fasting_blood_sugar_over_120=True, resting_ecg="normal", max_heart_rate=130,
              exercise_induced_angina=True, st_depression=1.4)),
        ("diabetes", 18.9, ["HbA1c is in the prediabetic range (5.7-6.4%)."],
         dict(age=52, sex="male", hypertension=True, heart_disease=False, smoking_history="former",
              bmi=29.5, hba1c_level=6.1, blood_glucose_level=126)),
    ],
    "siti@demo.com": [
        ("stroke", 9.3, ["Average glucose level is elevated (>= 140 mg/dL)."],
         dict(age=61, sex="female", hypertension=False, heart_disease=False, ever_married=True,
              work_type="Self-employed", residence_type="Rural", avg_glucose_level=165, bmi=27.0,
              smoking_status="never smoked")),
    ],
}


def _on_emulator() -> bool:
    return bool(os.getenv("FIRESTORE_EMULATOR_HOST")) and not os.getenv("FIREBASE_CREDENTIALS")


def _uid_for(email_or_uid: str) -> str:
    if "@" not in email_or_uid:
        return email_or_uid
    return auth.get_user_by_email(email_or_uid).uid


def cmd_seed(_):
    for u in DEMO_USERS:
        try:
            uid = auth.get_user_by_email(u["email"]).uid
            print(f"  exists   {u['email']}")
        except auth.UserNotFoundError:
            uid = auth.create_user(email=u["email"], password=DEMO_PASSWORD,
                                   display_name=u["name"]).uid
            print(f"  created  {u['email']}  (password: {DEMO_PASSWORD})")
        db.create_user_profile(uid, u["name"], u["email"], u["age"], u["sex"])
        if not db.list_deep_checks(uid, limit=1):
            for disease, risk, notes, inputs in DEMO_RESULTS.get(u["email"], []):
                db.save_deep_check(uid, disease, inputs, risk, notes, "seed-data")
    print("Seed done. Browse it at http://127.0.0.1:4000/firestore")


def cmd_users(_):
    for u in db.list_users():
        print(f"  {u['userID']}  {u.get('userEmail', '?'):22s} {u.get('userName', '?'):16s} "
              f"age {u.get('userAge', '?'):>3}  {u.get('userSex', '?')}")


def cmd_history(args):
    uid = _uid_for(args.user)
    rows = db.list_deep_checks(uid, args.disease)
    print(f"  {len(rows)} result(s) for {args.user}")
    for r in rows:
        # Firestore stores UTC; show local time
        when = r["created_at"].astimezone().strftime("%Y-%m-%d %H:%M") if r.get("created_at") else "?"
        print(f"  {when}  {r['diseaseType']:9s} {r['risk_percentage']:5.1f}%  "
              f"{r['resultID']}  ({r.get('modelName')})")


def cmd_token(args):
    """Sign in through the Auth emulator's REST API and print an ID token."""
    url = (f"http://{AUTH_HOST}/identitytoolkit.googleapis.com/v1/"
           f"accounts:signInWithPassword?key=demo-api-key")
    r = httpx.post(url, json={"email": args.email, "password": args.password,
                              "returnSecureToken": True})
    if r.status_code != 200:
        sys.exit(f"Sign-in failed: {r.json().get('error', {}).get('message', r.text)}")
    print(r.json()["idToken"])


def cmd_reset(_):
    if not _on_emulator():
        sys.exit("Refusing: reset only runs against the local emulator.")
    for u in db.list_users(limit=1000):
        db.delete_user_data(u["userID"])
    for u in auth.list_users().iterate_all():
        auth.delete_user(u.uid)
    print("All users, profiles and results deleted from the emulator.")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("seed", help="create demo users and sample history")
    sub.add_parser("users", help="list user profiles")
    h = sub.add_parser("history", help="list a user's deep-check results")
    h.add_argument("user", help="email or userID")
    h.add_argument("--disease", choices=db.DISEASE_TYPES)
    t = sub.add_parser("token", help="print an ID token (emulator sign-in)")
    t.add_argument("email")
    t.add_argument("--password", default=DEMO_PASSWORD)
    sub.add_parser("reset", help="delete everything (emulator only)")
    args = ap.parse_args()

    if not db.init_db():
        sys.exit("No database connection.")
    {"seed": cmd_seed, "users": cmd_users, "history": cmd_history,
     "token": cmd_token, "reset": cmd_reset}[args.cmd](args)


if __name__ == "__main__":
    main()
