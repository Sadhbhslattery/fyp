#REFERNCE 
from pydantic import BaseModel
from typing import Optional, Dict, Any

class SignupRequest(BaseModel):
    sail_no: str
    password: str
    owner_name: Optional[str] = None

class AdminLoginRequest(BaseModel):
    username: str
    password: str

class UserLoginRequest(BaseModel):
    sail_no: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

class BoatAuthResponse(BaseModel):
    success: bool = True
    message: str = "OK"
    role: str = "competitor"
    boat: Optional[Dict[str, Any]] = None

