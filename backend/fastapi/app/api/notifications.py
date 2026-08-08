from fastapi import APIRouter, Depends, Header, HTTPException, Query, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.notifications import (
    MarkClickedRequest,
    MarkViewedRequest,
    NotificationCreate,
    NotificationCreateResponse,
    NotificationFeedResponse,
    NotificationListResponse,
)
from ..services.notifications import (
    create_notification,
    delete_notification,
    list_user_notification_feed,
    list_notifications,
    mark_notification_viewed,
    mark_notification_clicked,
)

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> None:
    if not settings.admin_api_key:
        return
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")


@router.get("", response_model=NotificationListResponse)
def get_notifications(
    _: None = Depends(_require_admin_key),
    limit: int = Query(default=50, ge=1, le=200),
):
    items = list_notifications(get_supabase_client(), limit=limit)
    return NotificationListResponse(items=items)


@router.post("", response_model=NotificationCreateResponse, status_code=status.HTTP_201_CREATED)
def post_notification(
    payload: NotificationCreate,
    _: None = Depends(_require_admin_key),
):
    item = create_notification(get_supabase_client(), payload)
    return NotificationCreateResponse(item=item)


@router.get("/feed", response_model=NotificationFeedResponse)
def get_user_feed(
    user_id: str = Query(min_length=1),
    limit: int = Query(default=100, ge=1, le=300),
):
    items = list_user_notification_feed(get_supabase_client(), user_id=user_id, limit=limit)
    return NotificationFeedResponse(items=items)


@router.delete("/{notification_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_notification(
    notification_id: str,
    _: None = Depends(_require_admin_key),
):
    delete_notification(get_supabase_client(), notification_id)


@router.post("/{notification_id}/view", status_code=status.HTTP_204_NO_CONTENT)
def set_notification_viewed(
    notification_id: str,
    payload: MarkViewedRequest,
):
    mark_notification_viewed(get_supabase_client(), notification_id=notification_id, user_id=str(payload.user_id))


@router.post("/{notification_id}/click", status_code=status.HTTP_204_NO_CONTENT)
def set_notification_clicked(
    notification_id: str,
    payload: MarkClickedRequest,
):
    mark_notification_clicked(get_supabase_client(), notification_id=notification_id, user_id=str(payload.user_id))
