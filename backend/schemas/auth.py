#REFERENCE
from pydantic import BaseModel

class SignupRequest(BaseModel):
    sail_no: str
    password: str
    owner_name: str | None = None

class LoginRequest(BaseModel):
    sail_no: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
