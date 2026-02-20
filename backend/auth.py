# Password hashing and verification utilities for the Regatta backend.

# Authentication works as follows:
#   1. Competitor signs up via POST /signup - password is bcrypt-hashed and
#      stored in Boat.owner_password in the database.
#   2. Competitor logs in via POST /user-login - supplied password is verified
#      against the stored hash. The backend returns the boat object directly.
#   3. The Flutter app stores the boat object in memory for the session.
#   4. There is no token issued, no Authorisation header and no server-side
#      session table. The app is used in a single-race-day context where
#      persistent sessions across days are not required.

# Reference: passlib CryptContext for bcrypt hashing [B15]
# Reference: bcrypt algorithm [B16]

# Imports

from passlib.context import CryptContext
# CryptContext is passlib's high-level password hashing API.
# It wraps the bcrypt algorithm and exposes simple .hash() and .verify() methods.
# Reference: passlib CryptContext [B15]

from passlib.exc import UnknownHashError 
# UnknownHashError is raised when passlib cannot identify the format of a stored
# password string (e.g. a plain-text value stored before hashing was introduced).
# Imported here so other modules can catch it without importing passlib directly.
# Reference: passlib exceptions [B15]

# CryptContext Setup

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
# Creates a single, shared CryptContext instance used by both functions below.
# schemes=["bcrypt"] – only the bcrypt algorithm is accepted.
#   bcrypt is a deliberately slow, salted hashing algorithm designed for passwords.
#   Its computational cost makes brute-force and dictionary attacks expensive.
# deprecated="auto" – if a stronger scheme is added to schemes in the future,
#   passlib will automatically flag old hashes as needing rehashing.
# Reference: passlib CryptContext [B15]
# Reference: bcrypt algorithm design [B16]

# Public Functions

def hash_password(password: str) -> str:
    """
    Hash a plain-text password using bcrypt and return the hash string.

    The returned string has the format:
        $2b$12$<22-character-salt><31-character-hash>

    This full string is stored in Boat.owner_password in the database.
    It is safe to store because:
      - The salt is random for every call, so the same password produces a
        different hash each time (prevents rainbow-table attacks).
      - The hash cannot be reversed to recover the original password.

    Args:
        password: plain-text password supplied by the competitor at signup.

    Returns:
        A bcrypt hash string ready to be stored in the database.

    Reference: passlib hash() method [B15]
    Reference: bcrypt salt and cost factor [B16]
    """
    return pwd_context.hash(password)
    # pwd_context.hash() generates a random salt internally, runs bcrypt, and
    # returns the complete "$2b$..." string that includes the salt and hash.


def verify_password(plain_password: str, stored_password: str) -> bool:
    """
    Verify a plain-text password against a stored password string.

    Supports two cases to allow backward compatibility with any boats that
    had passwords stored before bcrypt hashing was introduced:

      1. Hashed passwords (new accounts):
         stored_password starts with "$2a$", "$2b$", or "$2y$".
         Uses passlib's constant-time bcrypt comparison.

      2. Legacy plain-text passwords (old data):
         stored_password does not match any bcrypt prefix.
         Falls back to a direct string comparison.

    Args:
        plain_password:  password typed by the competitor at login.
        stored_password: value from Boat.owner_password in the database.

    Returns:
        True if the password matches, False otherwise.

    Reference: passlib verify() method [B15]
    Reference: bcrypt hash prefix conventions ($2a$, $2b$, $2y$) [B16]
    """
    if stored_password is None:
        # No password has been set for this boat yet (owner_password is NULL).
        # Deny access – the competitor must sign up first.
        return False

    # Detect whether the stored value is a bcrypt hash by checking its prefix.
    # All three prefixes represent the same bcrypt algorithm:
    #   $2a$ – original bcrypt prefix
    #   $2b$ – current standard prefix, used by passlib by default
    #   $2y$ – PHP-originated prefix (same algorithm, different convention)
    if (stored_password.startswith("$2a$")
            or stored_password.startswith("$2b$")
            or stored_password.startswith("$2y$")):
        # Proper bcrypt hash: use passlib's verify() for constant-time comparison.
        # Constant-time means the function takes the same amount of time whether
        # the password is correct or not, preventing timing side-channel attacks.
        # Reference: passlib constant-time comparison [B15]
        return pwd_context.verify(plain_password, stored_password)

    # Legacy fallback: plain-text password stored before hashing was introduced.
    # New signups always produce a bcrypt hash, so this branch will be reached
    # less frequently over time as all boats re-register.
    return plain_password == stored_password
