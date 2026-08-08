from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.lessons import LessonCreate, LessonItem, LessonListResponse, LessonUpdate
from ..services.lessons import create_lesson, delete_lesson, list_lessons, update_lesson

router = APIRouter(prefix="/lessons", tags=["lessons"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> None:
    if not settings.admin_api_key:
        return
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")


@router.get("", response_model=LessonListResponse)
def get_lessons(course_id: str | None = Query(default=None)):
    return LessonListResponse(items=list_lessons(get_supabase_client(), course_id=course_id))


@router.post("", response_model=LessonItem, status_code=status.HTTP_201_CREATED)
def post_lesson(payload: LessonCreate, _: None = Depends(_require_admin_key)):
    return create_lesson(get_supabase_client(), payload)


@router.patch("/{lesson_id}", response_model=LessonItem)
def patch_lesson(lesson_id: str, payload: LessonUpdate, _: None = Depends(_require_admin_key)):
    return update_lesson(get_supabase_client(), lesson_id=lesson_id, payload=payload)


@router.delete("/{lesson_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_lesson(lesson_id: str, _: None = Depends(_require_admin_key)):
    delete_lesson(get_supabase_client(), lesson_id=lesson_id)
