from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.slides import SlideCreate, SlideItem, SlideListResponse, SlideUpdate
from ..services.slides import create_slide, delete_slide, list_slides, update_slide

router = APIRouter(prefix="/slides", tags=["slides"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> None:
    if not settings.admin_api_key:
        return
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")


@router.get("", response_model=SlideListResponse)
def get_slides(
    active_only: bool = Query(default=False),
):
    return SlideListResponse(items=list_slides(get_supabase_client(), active_only=active_only))


@router.post("", response_model=SlideItem, status_code=status.HTTP_201_CREATED)
def post_slide(
    payload: SlideCreate,
    _: None = Depends(_require_admin_key),
):
    return create_slide(get_supabase_client(), payload)


@router.patch("/{slide_id}", response_model=SlideItem)
def patch_slide(
    slide_id: str,
    payload: SlideUpdate,
    _: None = Depends(_require_admin_key),
):
    return update_slide(get_supabase_client(), slide_id=slide_id, payload=payload)


@router.delete("/{slide_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_slide(
    slide_id: str,
    _: None = Depends(_require_admin_key),
):
    delete_slide(get_supabase_client(), slide_id=slide_id)
