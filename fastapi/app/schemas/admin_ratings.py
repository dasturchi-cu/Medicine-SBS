from pydantic import BaseModel, Field


class AdminRatingItem(BaseModel):
    id: str
    course_id: str
    course_title: str
    user_id: str
    user_name: str
    stars: int
    created_at: str


class AdminRatingsResponse(BaseModel):
    items: list[AdminRatingItem]
    total: int


class AdminRatingsAnalyticsResponse(BaseModel):
    total_ratings: int
    average_stars: float
    five_star_count: int
    four_star_count: int
    low_rating_count: int


class AdminRatingsResetRequest(BaseModel):
    course_id: str | None = Field(default=None, min_length=1)
    user_id: str | None = Field(default=None, min_length=1)


class AdminRatingUpdateRequest(BaseModel):
    stars: int = Field(ge=1, le=5)
