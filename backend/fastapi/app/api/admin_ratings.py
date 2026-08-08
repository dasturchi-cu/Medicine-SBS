from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.admin_ratings import AdminRatingsAnalyticsResponse, AdminRatingsResetRequest, AdminRatingsResponse, AdminRatingUpdateRequest
from ..services.admin_ratings import delete_admin_rating, get_admin_ratings_analytics, list_admin_ratings, reset_admin_ratings, update_admin_rating

router = APIRouter(prefix="/admin/ratings", tags=["admin-ratings"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> None:
    if not settings.admin_api_key:
        return
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")


@router.get("", response_model=AdminRatingsResponse)
def get_ratings(
    search: str = Query(default=""),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    _: None = Depends(_require_admin_key),
):
    items, total = list_admin_ratings(get_supabase_client(), query=search, page=page, page_size=page_size)
    return AdminRatingsResponse(items=items, total=total)


@router.get("/analytics", response_model=AdminRatingsAnalyticsResponse)
def get_ratings_analytics(_: None = Depends(_require_admin_key)):
    return AdminRatingsAnalyticsResponse(**get_admin_ratings_analytics(get_supabase_client()))


@router.delete("/{rating_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_rating(rating_id: str, _: None = Depends(_require_admin_key)):
    delete_admin_rating(get_supabase_client(), rating_id=rating_id)


@router.patch("/{rating_id}", status_code=status.HTTP_204_NO_CONTENT)
def patch_rating(rating_id: str, payload: AdminRatingUpdateRequest, _: None = Depends(_require_admin_key)):
    update_admin_rating(get_supabase_client(), rating_id=rating_id, stars=payload.stars)


@router.post("/reset", status_code=status.HTTP_200_OK)
def reset_ratings(payload: AdminRatingsResetRequest, _: None = Depends(_require_admin_key)):
    deleted = reset_admin_ratings(get_supabase_client(), course_id=payload.course_id, user_id=payload.user_id)
    return {"deleted": deleted}
