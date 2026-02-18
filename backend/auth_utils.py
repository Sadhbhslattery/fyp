#REFERENCE
from passlib.context import CryptContext
from passlib.exc import UnknownHashError

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, stored_password: str) -> bool:
    """
    Supports both:
    - bcrypt hashed passwords (new)
    - legacy plain text passwords (old data in DB)
    """
    if stored_password is None:
        return False

    # If it looks like bcrypt, verify normally
    if stored_password.startswith("$2a$") or stored_password.startswith("$2b$") or stored_password.startswith("$2y$"):
        return pwd_context.verify(plain_password, stored_password)

    # Otherwise treat as legacy plain text
    return plain_password == stored_password

