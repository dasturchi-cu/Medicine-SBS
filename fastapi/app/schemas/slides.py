from datetime import datetime

from pydantic import BaseModel, Field


class SlideCreate(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    subtitle: str = ""
    image_url: str = ""
    button_text: str = "Boshlash"
    course_id: str | None = None
    order_no: int = Field(default=1, ge=1)


class SlideUpdate(BaseModel):
    title: str | None = None
    subtitle: str | None = None
    image_url: str | None = None
    button_text: str | None = None
    course_id: str | None = None
    order_no: int | None = Field(default=None, ge=1)
    is_active: bool | None = None


class SlideItem(BaseModel):
    id: str
    title: str
    subtitle: str
    image_url: str
    button_text: str
    course_id: str | None
    order_no: int
    is_active: bool
    created_at: datetime


class SlideListResponse(BaseModel):
    items: list[SlideItem]
