from pydantic import BaseModel


class MobileLesson(BaseModel):
    id: str
    title: str
    video_url: str
    duration_sec: int
    order_no: int
    is_free: bool


class MobileSection(BaseModel):
    id: str
    title: str
    order_no: int
    lessons: list[MobileLesson]


class MobileCourse(BaseModel):
    id: str
    title_uz: str
    title_ru: str
    title_en: str
    admin_telegram: str
    price_uzs: float
    image_url: str
    description_uz: str
    rating_avg: float = 0
    rating_count: int = 0
    sections: list[MobileSection]


class MobileCatalogResponse(BaseModel):
    items: list[MobileCourse]
