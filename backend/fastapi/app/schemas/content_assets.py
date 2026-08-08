from datetime import datetime

from pydantic import BaseModel, Field


class LessonAssetItem(BaseModel):
    id: str
    course_id: str | None = None
    lesson_id: str | None = None
    title: str
    description: str
    file_url: str
    file_type: str
    preview_image_url: str = ""
    order_no: int
    is_active: bool
    created_at: datetime


class LessonAssetsResponse(BaseModel):
    items: list[LessonAssetItem]


class LessonAssetCreate(BaseModel):
    course_id: str | None = None
    lesson_id: str | None = None
    title: str = Field(min_length=1, max_length=180)
    description: str = ""
    file_url: str = Field(min_length=1)
    file_type: str = Field(pattern="^(pdf|ppt)$")
    preview_image_url: str = ""
    order_no: int = 1
    is_active: bool = True


class LessonAssetUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    file_url: str | None = None
    file_type: str | None = None
    preview_image_url: str | None = None
    order_no: int | None = None
    is_active: bool | None = None


class BookItem(BaseModel):
    id: str
    title: str
    description: str
    cover_image_url: str
    file_url: str
    file_mime: str
    page_count: int
    author: str
    category_id: str | None = None
    category_name: str | None = None
    course_id: str | None = None
    lesson_id: str | None = None
    is_active: bool
    created_at: datetime


class BooksResponse(BaseModel):
    items: list[BookItem]


class BookCreate(BaseModel):
    title: str = Field(min_length=1, max_length=180)
    description: str = ""
    cover_image_url: str = ""
    file_url: str = Field(min_length=1)
    file_mime: str = "application/pdf"
    page_count: int = 0
    author: str = ""
    category_id: str | None = None
    course_id: str | None = None
    lesson_id: str | None = None
    is_active: bool = True


class BookUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    cover_image_url: str | None = None
    file_url: str | None = None
    file_mime: str | None = None
    page_count: int | None = None
    author: str | None = None
    category_id: str | None = None
    course_id: str | None = None
    lesson_id: str | None = None
    is_active: bool | None = None


class BookProgressItem(BaseModel):
    book_id: str
    user_id: str
    page_no: int
    progress_percent: float
    updated_at: datetime


class BookProgressUpsert(BaseModel):
    user_id: str = Field(min_length=1)
    page_no: int = 1
    progress_percent: float = 0


class BookProgressListResponse(BaseModel):
    items: list[BookProgressItem]


class SlideProgressItem(BaseModel):
    lesson_asset_id: str
    user_id: str
    page_no: int
    progress_percent: float
    updated_at: datetime


class SlideProgressUpsert(BaseModel):
    user_id: str = Field(min_length=1)
    page_no: int = 1
    progress_percent: float = 0


class SlideProgressListResponse(BaseModel):
    items: list[SlideProgressItem]


class BookCategoryItem(BaseModel):
    id: str
    name: str
    slug: str


class BookCategoriesResponse(BaseModel):
    items: list[BookCategoryItem]


class BookCategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    slug: str = Field(min_length=1, max_length=160)
