from datetime import datetime

from pydantic import BaseModel, Field


class CourseCreate(BaseModel):
    title_uz: str = Field(min_length=1, max_length=200)
    title_ru: str = ""
    title_en: str = ""
    price_uzs: float = Field(default=0, ge=0)
    admin_telegram: str = "Mr_Xusanboy"
    image_url: str = ""
    description_uz: str = ""


class CourseUpdate(BaseModel):
    title_uz: str | None = None
    title_ru: str | None = None
    title_en: str | None = None
    price_uzs: float | None = Field(default=None, ge=0)
    admin_telegram: str | None = None
    image_url: str | None = None
    description_uz: str | None = None
    is_active: bool | None = None


class CourseItem(BaseModel):
    id: str
    title_uz: str
    title_ru: str
    title_en: str
    price_uzs: float
    admin_telegram: str
    image_url: str
    description_uz: str = ""
    is_active: bool
    views: int = 0
    sales: int = 0
    created_at: datetime


class CourseListResponse(BaseModel):
    items: list[CourseItem]


class CourseStatsResponse(BaseModel):
    course_id: str
    enrolled_count: int
    comments_count: int = 0
    rating_avg: float = 0
    rating_count: int = 0
    my_rating: int | None = None


class CourseRateRequest(BaseModel):
    user_id: str = Field(min_length=1)
    stars: int = Field(ge=1, le=5)


class CourseViewTrackRequest(BaseModel):
    user_id: str = Field(min_length=1)
    lesson_id: str = Field(min_length=1)
    watched_sec: int = Field(default=0, ge=0)
    completed: bool = False


class CourseViewTrackResponse(BaseModel):
    course_id: str
    views: int


class CourseCatalogOpenRequest(BaseModel):
    user_id: str = Field(min_length=1)


class CourseCatalogOpenResponse(BaseModel):
    course_id: str
    views: int


class CourseVideoProgressItem(BaseModel):
    course_id: str
    lesson_id: str
    watched_sec: int = 0
    completed: bool = False


class CourseVideoProgressResponse(BaseModel):
    items: list[CourseVideoProgressItem]


class SectionProgressItem(BaseModel):
    section_id: str
    total_lessons: int = 0
    completed_lessons: int = 0
    progress_percent: float = 0


class SectionProgressResponse(BaseModel):
    course_id: str
    user_id: str
    items: list[SectionProgressItem]
