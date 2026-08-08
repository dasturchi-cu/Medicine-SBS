from pydantic import BaseModel, Field


class FeedbackStatsResponse(BaseModel):
    content_key: str
    comments_count: int = 0
    rating_avg: float = 0
    rating_count: int = 0
    my_rating: int | None = None


class FeedbackRateRequest(BaseModel):
    user_id: str = Field(min_length=1)
    stars: int = Field(ge=1, le=5)
