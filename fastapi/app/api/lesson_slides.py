from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.lesson_slides import LessonSlideCreate, LessonSlideItem, LessonSlideListResponse, LessonSlideUpdate
from ..services.lesson_slides import create_lesson_slide, delete_lesson_slide, list_lesson_slides, update_lesson_slide

router = APIRouter(prefix="/lesson-slides", tags=["lesson-slides"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> None:
    if not settings.admin_api_key:
        return
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")


@router.get("", response_model=LessonSlideListResponse)
def get_lesson_slides(
    lesson_id: str = Query(min_length=1),
    active_only: bool = Query(default=True),
):
    items = list_lesson_slides(get_supabase_client(), lesson_id=lesson_id, active_only=active_only)
    return LessonSlideListResponse(items=items)


@router.post("", response_model=LessonSlideItem, status_code=status.HTTP_201_CREATED)
def post_lesson_slide(
    payload: LessonSlideCreate,
    _: None = Depends(_require_admin_key),
):
    return create_lesson_slide(get_supabase_client(), payload)


@router.patch("/{slide_id}", response_model=LessonSlideItem)
def patch_lesson_slide(
    slide_id: str,
    payload: LessonSlideUpdate,
    _: None = Depends(_require_admin_key),
):
    return update_lesson_slide(get_supabase_client(), slide_id=slide_id, payload=payload)


@router.delete("/{slide_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_lesson_slide(
    slide_id: str,
    _: None = Depends(_require_admin_key),
):
    delete_lesson_slide(get_supabase_client(), slide_id=slide_id)
