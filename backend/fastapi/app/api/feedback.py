import logging

from fastapi import APIRouter, HTTPException, Query, status

from ..db import get_supabase_client
from ..schemas.feedback import FeedbackRateRequest, FeedbackStatsResponse
from ..services.feedback import get_feedback_stats, upsert_feedback_rating

router = APIRouter(prefix="/feedback", tags=["feedback"])
logger = logging.getLogger(__name__)


@router.get("/{content_key}/stats", response_model=FeedbackStatsResponse)
def get_stats(content_key: str, user_id: str | None = Query(default=None)):
    logger.info("feedback.stats request content_key=%s user_id=%s", content_key, user_id or "")
    comments_count, rating_avg, rating_count, my_rating = get_feedback_stats(
        get_supabase_client(),
        content_key=content_key,
        user_id=user_id,
    )
    logger.info(
        "feedback.stats response content_key=%s comments=%s rating_avg=%s rating_count=%s",
        content_key,
        comments_count,
        rating_avg,
        rating_count,
    )
    return FeedbackStatsResponse(
        content_key=content_key,
        comments_count=comments_count,
        rating_avg=rating_avg,
        rating_count=rating_count,
        my_rating=my_rating,
    )


@router.post("/{content_key}/rate", status_code=status.HTTP_204_NO_CONTENT)
def post_rate(content_key: str, payload: FeedbackRateRequest):
    logger.info(
        "feedback.rate request content_key=%s user_id=%s stars=%s",
        content_key,
        payload.user_id,
        payload.stars,
    )
    try:
        upsert_feedback_rating(
            get_supabase_client(),
            content_key=content_key,
            user_id=payload.user_id,
            stars=payload.stars,
        )
    except Exception as error:
        logger.exception("feedback.rate failed: %s", error)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
    logger.info("feedback.rate response content_key=%s user_id=%s", content_key, payload.user_id)
