from pydantic import BaseModel


class RankingItem(BaseModel):
    user_id: str
    full_name: str
    total_score: float
    quiz_minutes: float
    rank: int


class RankingResponse(BaseModel):
    items: list[RankingItem]
