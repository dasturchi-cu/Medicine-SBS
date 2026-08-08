from fastapi import APIRouter, Depends, Header, HTTPException, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.admin_ads import AdminAdCreate, AdminAdItem, AdminAdListResponse, AdminAdUpdate
from ..services.admin_ads import create_ad, delete_ad, list_ads, update_ad

router = APIRouter(prefix="/admin/ads", tags=["admin-ads"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> None:
    if not settings.admin_api_key:
        return
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")


@router.get("", response_model=AdminAdListResponse)
def get_ads(_: None = Depends(_require_admin_key)):
    return AdminAdListResponse(items=list_ads(get_supabase_client()))


@router.post("", response_model=AdminAdItem, status_code=status.HTTP_201_CREATED)
def post_ad(payload: AdminAdCreate, _: None = Depends(_require_admin_key)):
    try:
        return create_ad(get_supabase_client(), payload)
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.patch("/{ad_id}", response_model=AdminAdItem)
def patch_ad(ad_id: str, payload: AdminAdUpdate, _: None = Depends(_require_admin_key)):
    try:
        return update_ad(get_supabase_client(), ad_id=ad_id, payload=payload)
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.delete("/{ad_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_ad(ad_id: str, _: None = Depends(_require_admin_key)):
    delete_ad(get_supabase_client(), ad_id=ad_id)
