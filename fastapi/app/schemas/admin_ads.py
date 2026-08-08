from datetime import datetime
from pydantic import BaseModel, Field, field_validator


class AdminAdCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    message: str = ""
    image_url: str = ""
    price_label: str = ""
    course_id: str | None = None
    telegram: str = "Mr_Xusanboy"
    is_active: bool = False

    @field_validator("course_id", mode="before")
    @classmethod
    def _empty_course(cls, v):
        if v is None:
            return None
        if isinstance(v, str) and not v.strip():
            return None
        return v


class AdminAdUpdate(BaseModel):
    title: str | None = None
    message: str | None = None
    image_url: str | None = None
    price_label: str | None = None
    course_id: str | None = None
    telegram: str | None = None
    is_active: bool | None = None


class AdminAdItem(BaseModel):
    id: str
    title: str
    message: str
    image_url: str
    price_label: str
    course_id: str | None = None
    telegram: str
    is_active: bool
    created_at: datetime


class AdminAdListResponse(BaseModel):
    items: list[AdminAdItem]
