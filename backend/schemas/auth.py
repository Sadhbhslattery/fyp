# Pydantic request and response schemas for all authentication-related endpoints.

# The schemas here cover:
#   - Competitor signup  (POST /signup, POST /boat-signup)
#   - Competitor login  (POST /user-login, POST /boat-login)
#   - Admin login  (POST /login)

# Authentication flow for competitors:
#   SignupRequest  - backend hashes password, stores in Boat.owner_password
#   UserLoginRequest - backend verifies password, returns BoatAuthResponse
#   Flutter stores the returned boat dict in memory for the session.
#   No token is issued and no Authorization header is required.

# Reference: Pydantic v2 models and field validation [B3]
# Reference: FastAPI request body and response_model [B1]

# Imports

from pydantic import BaseModel
# BaseModel is the base class for all Pydantic schemas.
# Subclassing it gives automatic JSON parsing, type coercion, and validation
# when FastAPI receives a request body that matches the schema.
# Reference: Pydantic BaseModel [B3]

from typing import Optional, Dict, Any
# Optional[X] – the field is either type X or None; can be omitted in JSON.
# Dict[str, Any] – a dictionary with string keys and values of any type.
#                Used for the nested boat object because its fields vary
#                slightly between the signup and login response shapes.
# Reference: Python typing module [B18]


# Request Models
# These are used as FastAPI body parameters (the JSON the Flutter app sends).


class SignupRequest(BaseModel):
    """
    Request body for POST /signup and POST /boat-signup.

    Sent by the Flutter SignupPage when a competitor creates an account
    for the first time.  The sail_no must already exist in the Boat table
    (added by the race officer) before signup is possible.

    Reference: FastAPI request body [B1]
    Reference: SignupPage Flutter implementation [F4]
    """

    sail_no: str
    # The boat's sail number, e.g. "IRL5355".
    # Used to look up the existing Boat row in the database.
    # If no matching row exists the endpoint raises HTTP 404.

    password: str
    # Plain-text password chosen by the competitor.
    # The endpoint immediately passes this to hash_password() before storing it.
    # It is never stored in plain text.
    # Reference: auth.py hash_password() [B15]

    owner_name: Optional[str] = None
    # The competitor's real name, e.g. "Jane Murphy".  Optional.
    # If omitted (or sent as null), the Boat.owner_name column is left unchanged.
    # Reference: Pydantic Optional fields [B3]


class AdminLoginRequest(BaseModel):
    """
    Request body for POST /login (race officer / admin login).

    Sent by the Flutter LoginPage.  Credentials are checked against
    hardcoded values in app.py (username="admin", password="password123").
    This is intentionally simple for this iteration.

    Reference: FastAPI request body [B1]
    Reference: LoginPage Flutter implementation [F4]
    """

    username: str
    # Admin username string. Currently matched against the literal "admin".

    password: str
    # Admin password string. Currently matched against "password123".


class UserLoginRequest(BaseModel):
    """
    Request body for POST /user-login (competitor login).

    Sent by the Flutter UserLoginPage. The backend looks up the Boat row
    by sail_no and verifies the supplied password against the stored bcrypt hash.

    Reference: FastAPI request body [B1]
    Reference: UserLoginPage Flutter implementation [F4]
    Reference: auth.py verify_password() [B15]
    """

    sail_no: str
    # The boat's sail number.
    # Converted to upper-case in the endpoint before the database query.

    password: str
    # Plain-text password supplied by the competitor.
    # Passed to verify_password() and never logged or stored.
    # Reference: auth.py verify_password() [B15]


# Response Models
# These are used as FastAPI response_model values (the JSON the app receives).

class BoatAuthResponse(BaseModel):
    """
    Response schema for POST /boat-signup and POST /boat-login.

    The Flutter client reads `success` first to decide whether to proceed,
    then uses the `boat` dict to populate the UserBoatPage dashboard.

    On failure (success=False) the `boat` field is None and `message`
    contains a user-readable explanation.

    Reference: Pydantic BaseModel [B3]
    Reference: FastAPI response_model [B1]
    """

    success: bool = True
    # True - operation succeeded: Flutter navigates to the competitor dashboard.
    # False - operation failed: Flutter shows the message as an error.
    # Defaults to True so endpoints that only return a boat dict still validate.

    message: str = "OK"
    # Human-readable status description shown in the Flutter UI.
    # Examples:
    #   "Signup successful. You can now log in anytime."
    #   "No boat found with that sail number."
    #   "This boat already has an account. Please log in."
    # Defaults to "OK" for straightforward successful responses.

    boat: Optional[Dict[str, Any]] = None
    # The boat data returned on success, containing fields such as:
    #   id, sail_no, name, class_name, rating_value
    # None when success is False – there is no boat to return on failure.
    # Dict[str, Any] is used so the same response model works for both
    # signup and login, which return slightly different subsets of boat fields.
    # Reference: Pydantic Optional fields [B3]
    # Reference: Python typing Dict / Any [B18]
