# REFERENCE
from datetime import datetime, timedelta, timezone
from passlib.context import CryptContext
from jose import jwt
from pydantic import BaseModel
from typing import Optional, Any

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Put this in Railway env vars later (Step 6)
JWT_SECRET = "CHANGE_ME"
JWT_ALG = "HS256"
JWT_EXPIRE_DAYS = 30

def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(password: str, hashed: str) -> bool:
    return pwd_context.verify(password, hashed)

def create_access_token(data: dict) -> str:
    payload = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(days=JWT_EXPIRE_DAYS)
    payload["exp"] = expire
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)


class BoatAuthResponse(BaseModel):
    success: bool
    message: str
    boat: Optional[dict] = None