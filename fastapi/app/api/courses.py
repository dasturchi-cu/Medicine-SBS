import logging

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.courses import (
    CourseCatalogOpenRequest,
    CourseCatalogOpenResponse,
    SectionProgressResponse,
    CourseVideoProgressResponse,
    CourseCreate,
    CourseItem,
    CourseListResponse,
    CourseRateRequest,
    CourseStatsResponse,
    CourseUpdate,
    CourseViewTrackRequest,
    CourseViewTrackResponse,
)
from ..services.courses import (
    create_course,
    delete_course,
    get_course_comments_count,
    get_course_enrolled_count,
    get_course_rating_summary,
    list_courses,
    record_catalog_view,
    list_section_progress,
    list_user_video_progress,
    track_course_view,
    update_course,
    upsert_course_rating,
)

router = APIRouter(prefix="/courses", tags=["courses"])
logger = logging.getLogger(__name__)


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> None:
    if not settings.admin_api_key:
        return
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")


@router.get("", response_model=CourseListResponse)
def get_courses(active_only: bool = Query(default=False)):
    logger.info("courses.list request active_only=%s", active_only)
    items = list_courses(get_supabase_client(), active_only=active_only)
    logger.info("courses.list response count=%s", len(items))
    return CourseListResponse(items=items)


@router.post("", response_model=CourseItem, status_code=status.HTTP_201_CREATED)
def post_course(payload: CourseCreate, _: None = Depends(_require_admin_key)):
    logger.info("courses.create request title_uz=%s", payload.title_uz)
    result = create_course(get_supabase_client(), payload)
    logger.info("courses.create response id=%s", result.id)
    return result


@router.patch("/{course_id}", response_model=CourseItem)
def patch_course(course_id: str, payload: CourseUpdate, _: None = Depends(_require_admin_key)):
    logger.info("courses.update request course_id=%s", course_id)
    try:
        result = update_course(get_supabase_client(), course_id=course_id, payload=payload)
    except RuntimeError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
    logger.info("courses.update response course_id=%s", result.id)
    return result


@router.delete("/{course_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_course(course_id: str, _: None = Depends(_require_admin_key)):
    logger.info("courses.delete request course_id=%s", course_id)
    delete_course(get_supabase_client(), course_id=course_id)
    logger.info("courses.delete response course_id=%s", course_id)


@router.get("/{course_id}/stats", response_model=CourseStatsResponse)
def get_course_stats(course_id: str, user_id: str | None = Query(default=None)):
    logger.info("courses.stats request course_id=%s user_id=%s", course_id, user_id or "")
    enrolled_count = get_course_enrolled_count(get_supabase_client(), course_id=course_id)
    comments_count = get_course_comments_count(get_supabase_client(), course_id=course_id)
    rating_avg, rating_count, my_rating = get_course_rating_summary(get_supabase_client(), course_id=course_id, user_id=user_id)
    logger.info(
        "courses.stats response course_id=%s enrolled=%s comments=%s rating_avg=%s rating_count=%s",
        course_id,
        enrolled_count,
        comments_count,
        rating_avg,
        rating_count,
    )
    return CourseStatsResponse(
        course_id=course_id,
        enrolled_count=enrolled_count,
        comments_count=comments_count,
        rating_avg=rating_avg,
        rating_count=rating_count,
        my_rating=my_rating,
    )


@router.post("/{course_id}/rate", status_code=status.HTTP_204_NO_CONTENT)
def post_course_rating(course_id: str, payload: CourseRateRequest):
    logger.info("courses.rate request course_id=%s user_id=%s stars=%s", course_id, payload.user_id, payload.stars)
    try:
        upsert_course_rating(get_supabase_client(), course_id=course_id, user_id=payload.user_id, stars=payload.stars)
    except Exception as error:
        logger.exception("courses.rate failed: %s", error)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
    logger.info("courses.rate response course_id=%s user_id=%s", course_id, payload.user_id)


@router.post("/{course_id}/views", response_model=CourseViewTrackResponse)
def post_course_view(course_id: str, payload: CourseViewTrackRequest):
    logger.info(
        "courses.view request course_id=%s lesson_id=%s user_id=%s watched_sec=%s completed=%s",
        course_id,
        payload.lesson_id,
        payload.user_id,
        payload.watched_sec,
        payload.completed,
    )
    try:
        views = track_course_view(
            get_supabase_client(),
            course_id=course_id,
            lesson_id=payload.lesson_id,
            user_id=payload.user_id,
            watched_sec=payload.watched_sec,
            completed=payload.completed,
        )
    except RuntimeError as error:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
    logger.info("courses.view response course_id=%s views=%s", course_id, views)
    return CourseViewTrackResponse(course_id=course_id, views=views)


@router.post("/{course_id}/catalog-open", response_model=CourseCatalogOpenResponse)
def post_course_catalog_open(course_id: str, payload: CourseCatalogOpenRequest):
    """Record that the user opened the course screen (deduped per user+course). Updates aggregate views."""
    logger.info("courses.catalog_open request course_id=%s user_id=%s", course_id, payload.user_id)
    try:
        views = record_catalog_view(get_supabase_client(), course_id=course_id, user_id=payload.user_id)
    except Exception as error:
        logger.exception("courses.catalog_open failed: %s", error)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error)) from error
    logger.info("courses.catalog_open response course_id=%s views=%s", course_id, views)
    return CourseCatalogOpenResponse(course_id=course_id, views=views)


@router.get("/progress", response_model=CourseVideoProgressResponse)
def get_user_video_progress(
    user_id: str = Query(min_length=1),
    course_id: str | None = Query(default=None),
    lesson_id: str | None = Query(default=None),
):
    items = list_user_video_progress(
        get_supabase_client(),
        user_id=user_id,
        course_id=course_id,
        lesson_id=lesson_id,
    )
    return CourseVideoProgressResponse(items=items)


@router.get("/{course_id}/sections/progress", response_model=SectionProgressResponse)
def get_section_progress(course_id: str, user_id: str = Query(min_length=1)):
    items = list_section_progress(
        get_supabase_client(),
        course_id=course_id,
        user_id=user_id,
    )
    return SectionProgressResponse(course_id=course_id, user_id=user_id, items=items)
