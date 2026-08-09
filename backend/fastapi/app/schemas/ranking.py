from pydantic import BaseModel, Field


class StudyRecordRequest(BaseModel):
    """Pomodoro (yoki boshqa) o'qish vaqtini reytingga qo'shish uchun."""

    user_id: str = Field(min_length=1)
    seconds: int = Field(ge=1, le=86400)


class RankingItem(BaseModel):
    user_id: str
    full_name: str
    total_score: float
    quiz_minutes: float
    rank: int


class RankingResponse(BaseModel):
    items: list[RankingItem]
