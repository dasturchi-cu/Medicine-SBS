from fastapi import APIRouter, Query

from ..db import get_supabase_client
from ..schemas.ranking import RankingResponse
from ..services.ranking import list_ranking

router = APIRouter(prefix="/ranking", tags=["ranking"])


@router.get("", response_model=RankingResponse)
def get_ranking(
    limit: int = Query(default=50, ge=1, le=200),
    period: str = Query(
        default="overall",
        pattern="^(daily|weekly|monthly|yearly|overall)$",
    ),
):
    return RankingResponse(
        items=list_ranking(get_supabase_client(), limit=limit, period=period)
    )
