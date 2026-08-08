from fastapi import APIRouter, Depends, Header, HTTPException, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.admin_comments import AdminCommentItem, AdminCommentReplyRequest, AdminCommentsResponse
from ..services.admin_comments import add_admin_reply, delete_admin_comment, list_admin_comments, toggle_admin_heart

router = APIRouter(prefix="/admin/comments", tags=["admin-comments"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> Settings:
    if settings.admin_api_key and x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")
    return settings


@router.get("", response_model=AdminCommentsResponse)
def get_admin_comments(settings: Settings = Depends(_require_admin_key)):
    try:
        items = list_admin_comments(get_supabase_client(), configured_admin_user_id=settings.admin_user_id)
    except Exception:
        items = []
    return AdminCommentsResponse(items=items)


@router.post("/{comment_id}/reply", response_model=AdminCommentItem, status_code=status.HTTP_201_CREATED)
def post_admin_reply(comment_id: str, payload: AdminCommentReplyRequest, settings: Settings = Depends(_require_admin_key)):
    return add_admin_reply(
        get_supabase_client(),
        comment_id=comment_id,
        text=payload.text,
        configured_admin_user_id=settings.admin_user_id,
    )


@router.post("/{comment_id}/toggle-heart", response_model=AdminCommentItem)
def post_admin_toggle_heart(comment_id: str, settings: Settings = Depends(_require_admin_key)):
    return toggle_admin_heart(get_supabase_client(), comment_id=comment_id, configured_admin_user_id=settings.admin_user_id)


@router.delete("/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_admin_comment(comment_id: str, _: Settings = Depends(_require_admin_key)):
    delete_admin_comment(get_supabase_client(), comment_id=comment_id)
