from datetime import datetime

from pydantic import BaseModel, Field


class BannerCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    message: str = ""
    image_url: str = ""
    price_label: str = ""
    course_id: str | None = None
    telegram: str = "Mr_Xusanboy"
    is_active: bool = False


class BannerUpdate(BaseModel):
    title: str | None = None
    message: str | None = None
    image_url: str | None = None
    price_label: str | None = None
    course_id: str | None = None
    telegram: str | None = None
    is_active: bool | None = None


class BannerItem(BaseModel):
    id: str
    title: str
    message: str
    image_url: str
    price_label: str
    course_id: str | None
    telegram: str
    is_active: bool
    created_at: datetime


class BannerListResponse(BaseModel):
    items: list[BannerItem]
