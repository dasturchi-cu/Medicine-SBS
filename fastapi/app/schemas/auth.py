from pydantic import BaseModel, Field


class MobileLoginRequest(BaseModel):
    phone: str = Field(min_length=5)
    password: str = ""
    display_name: str = ""
    device_id: str = Field(min_length=1)
    platform: str = "android"
    fcm_token: str | None = None


class AuthUserResponse(BaseModel):
    user_id: str
    phone: str
    full_name: str
    session_token: str


class MobileProfileUpdateRequest(BaseModel):
    user_id: str = Field(min_length=1)
    session_token: str = Field(min_length=8)
    display_name: str = Field(min_length=1, max_length=200)


class UserStatusResponse(BaseModel):
    user_id: str
    is_blocked: bool
    admin_contact: str
    session_active: bool = True
