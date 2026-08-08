from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.banners import BannerCreate, BannerItem, BannerListResponse, BannerUpdate
from ..services.banners import create_banner, delete_banner, list_banners, update_banner

router = APIRouter(prefix="/banners", tags=["banners"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> None:
    if not settings.admin_api_key:
        return
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")


@router.get("", response_model=BannerListResponse)
def get_banners(active_only: bool = Query(default=False)):
    return BannerListResponse(items=list_banners(get_supabase_client(), active_only=active_only))


@router.post("", response_model=BannerItem, status_code=status.HTTP_201_CREATED)
def post_banner(payload: BannerCreate, _: None = Depends(_require_admin_key)):
    return create_banner(get_supabase_client(), payload)


@router.patch("/{banner_id}", response_model=BannerItem)
def patch_banner(banner_id: str, payload: BannerUpdate, _: None = Depends(_require_admin_key)):
    return update_banner(get_supabase_client(), banner_id=banner_id, payload=payload)


@router.delete("/{banner_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_banner(banner_id: str, _: None = Depends(_require_admin_key)):
    delete_banner(get_supabase_client(), banner_id=banner_id)
