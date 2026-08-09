from fastapi import APIRouter, Query, status

from ..db import get_supabase_client
from ..schemas.ranking import RankingResponse, StudyRecordRequest
from ..services.ranking import list_ranking, record_study_seconds

router = APIRouter(prefix="/ranking", tags=["ranking"])


@router.post("/study", status_code=status.HTTP_204_NO_CONTENT)
def post_study(payload: StudyRecordRequest):
    """Pomodoro/o'qish vaqtini reytingga qo'shadi."""
    record_study_seconds(get_supabase_client(), user_id=payload.user_id, seconds=payload.seconds)


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
