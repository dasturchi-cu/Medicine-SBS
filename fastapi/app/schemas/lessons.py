from datetime import datetime

from pydantic import BaseModel, Field


class LessonCreate(BaseModel):
    course_id: str = Field(min_length=1)
    section_id: str | None = None
    title: str = Field(min_length=1, max_length=300)
    video_url: str = ""
    order_no: int = Field(default=1, ge=1)
    is_free: bool = False


class LessonUpdate(BaseModel):
    course_id: str | None = None
    section_id: str | None = None
    title: str | None = None
    video_url: str | None = None
    order_no: int | None = Field(default=None, ge=1)
    is_free: bool | None = None


class LessonItem(BaseModel):
    id: str
    course_id: str
    section_id: str | None
    title: str
    video_url: str
    order_no: int
    is_free: bool
    created_at: datetime


class LessonListResponse(BaseModel):
    items: list[LessonItem]
