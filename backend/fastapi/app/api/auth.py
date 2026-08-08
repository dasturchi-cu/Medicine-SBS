from fastapi import APIRouter, Depends, Query

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.auth import AuthUserResponse, MobileLoginRequest, MobileProfileUpdateRequest, UserStatusResponse
from ..services.auth import get_user_status, mobile_login, update_mobile_profile

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/mobile-login", response_model=AuthUserResponse)
def post_mobile_login(payload: MobileLoginRequest, settings: Settings = Depends(get_settings)):
    return mobile_login(get_supabase_client(), payload, admin_contact=settings.admin_contact_telegram)


@router.patch("/mobile-profile", response_model=AuthUserResponse)
def patch_mobile_profile(payload: MobileProfileUpdateRequest):
    return update_mobile_profile(get_supabase_client(), payload)


@router.get("/user-status/{user_id}", response_model=UserStatusResponse)
def get_mobile_user_status(user_id: str, settings: Settings = Depends(get_settings)):
    return get_user_status(
        get_supabase_client(),
        user_id=user_id,
        admin_contact=settings.admin_contact_telegram,
    )


@router.get("/session-status/{user_id}", response_model=UserStatusResponse)
def get_mobile_session_status(
    user_id: str,
    session_token: str = Query(min_length=8),
    settings: Settings = Depends(get_settings),
):
    return get_user_status(
        get_supabase_client(),
        user_id=user_id,
        admin_contact=settings.admin_contact_telegram,
        session_token=session_token,
    )
