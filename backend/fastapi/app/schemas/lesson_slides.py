from datetime import datetime

from pydantic import BaseModel, Field


class LessonSlideCreate(BaseModel):
    lesson_id: str = Field(min_length=1)
    title: str = Field(min_length=1, max_length=240)
    body: str = ""
    image_url: str = ""
    order_no: int = Field(default=1, ge=1)


class LessonSlideUpdate(BaseModel):
    title: str | None = None
    body: str | None = None
    image_url: str | None = None
    order_no: int | None = Field(default=None, ge=1)
    is_active: bool | None = None


class LessonSlideItem(BaseModel):
    id: str
    lesson_id: str
    title: str
    body: str
    image_url: str
    order_no: int
    is_active: bool
    created_at: datetime


class LessonSlideListResponse(BaseModel):
    items: list[LessonSlideItem]
