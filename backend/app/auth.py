"""Firebase Auth for the API.

The Flutter app signs in with Firebase Auth, then sends its ID token on each
request:   Authorization: Bearer <idToken>
The backend verifies the token and gets the user's uid from it - the app can
never just *claim* to be a user. With FIREBASE_AUTH_EMULATOR_HOST set, tokens
from the local Auth emulator are accepted instead of real ones.

Using FastAPI's HTTPBearer scheme also adds an "Authorize" button to /docs:
paste a token there once and every request in the page sends it.
"""
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth

from backend.app import db

_bearer = HTTPBearer(auto_error=False, description="Firebase ID token")


def optional_uid(creds: HTTPAuthorizationCredentials | None = Depends(_bearer)) -> str | None:
    """uid of the signed-in user, or None if no token was sent (anonymous use)."""
    if creds is None:
        return None
    if not db.enabled():
        raise HTTPException(503, "Database/auth is not configured on this server.")
    try:
        return auth.verify_id_token(creds.credentials)["uid"]
    except Exception as exc:          # expired, malformed, wrong project, revoked...
        raise HTTPException(401, f"Invalid or expired token: {type(exc).__name__}")


def required_uid(uid: str | None = Depends(optional_uid)) -> str:
    """Same as optional_uid, but the endpoint needs a signed-in user."""
    if uid is None:
        raise HTTPException(401, "Sign in required (send 'Authorization: Bearer <idToken>').")
    return uid
