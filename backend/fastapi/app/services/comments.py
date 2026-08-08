from __future__ import annotations

from datetime import datetime
from typing import Any

from ..neon_client import Client

from ..schemas.comments import AppCommentItem, AddCommentRequest


def _to_item(row: dict[str, Any], *, liked_by_me: bool, liked_by_admin: bool = False) -> AppCommentItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    return AppCommentItem(
        id=str(row.get("id") or ""),
        course_key=str(row.get("course_key") or ""),
        user_id=str(row.get("user_id") or ""),
        author_name=str(row.get("author_name") or ""),
        text=str(row.get("text") or ""),
        parent_id=str(row.get("parent_id")) if row.get("parent_id") else None,
        replies_count=int(row.get("replies_count") or 0),
        likes_count=int(row.get("likes_count") or 0),
        liked_by_me=liked_by_me,
        liked_by_admin=liked_by_admin,
        created_at=created,
    )


def list_comments(
    client: Client,
    *,
    course_key: str,
    user_id: str | None = None,
    admin_user_id: str | None = None,
) -> list[AppCommentItem]:
    rows = (
        client.table("app_comments")
        .select("*")
        .eq("course_key", course_key)
        .order("created_at", desc=True)
        .limit(200)
        .execute()
    ).data or []
    if not rows:
        return []

    comment_ids = [str(row.get("id") or "") for row in rows if row.get("id")]
    liked_ids: set[str] = set()
    if user_id:
        likes = (
            client.table("app_comment_likes")
            .select("comment_id")
            .eq("user_id", user_id)
            .in_("comment_id", comment_ids)
            .execute()
        ).data or []
        liked_ids = {str(row.get("comment_id")) for row in likes}

    admin_liked_ids: set[str] = set()
    admin_uid = (admin_user_id or "").strip()
    if admin_uid:
        admin_likes = (
            client.table("app_comment_likes")
            .select("comment_id")
            .eq("user_id", admin_uid)
            .in_("comment_id", comment_ids)
            .execute()
        ).data or []
        admin_liked_ids = {str(row.get("comment_id")) for row in admin_likes}

    return [
        _to_item(
            row,
            liked_by_me=str(row.get("id") or "") in liked_ids,
            liked_by_admin=str(row.get("id") or "") in admin_liked_ids,
        )
        for row in rows
    ]


def add_comment(client: Client, payload: AddCommentRequest) -> AppCommentItem:
    parent_id = (payload.parent_id or "").strip() or None
    resolved_course_key = payload.course_key
    if parent_id:
        parent = (
            client.table("app_comments")
            .select("id,course_key")
            .eq("id", parent_id)
            .limit(1)
            .execute()
        ).data or []
        if not parent:
            raise RuntimeError("Reply uchun ota izoh topilmadi.")
        resolved_course_key = str(parent[0].get("course_key") or payload.course_key or "")
        if not resolved_course_key:
            raise RuntimeError("Reply uchun course_key aniqlanmadi.")

    inserted = (
        client.table("app_comments")
        .insert(
            {
                "course_key": resolved_course_key,
                "user_id": payload.user_id,
                "author_name": payload.author_name.strip(),
                "text": payload.text.strip(),
                "parent_id": parent_id,
            }
        )
        .execute()
    )
    row = (inserted.data or [None])[0]
    if not row:
        raise RuntimeError("Failed to add comment.")
    if parent_id:
        replies_count = int(
            (
                client.table("app_comments")
                .select("id", count="exact")
                .eq("parent_id", parent_id)
                .execute()
            ).count
            or 0
        )
        client.table("app_comments").update({"replies_count": replies_count}).eq("id", parent_id).execute()
    return _to_item(row, liked_by_me=False, liked_by_admin=False)


def toggle_like(client: Client, *, comment_id: str, user_id: str) -> AppCommentItem:
    existing = (
        client.table("app_comment_likes")
        .select("id")
        .eq("comment_id", comment_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    ).data or []

    if existing:
        client.table("app_comment_likes").delete().eq("comment_id", comment_id).eq("user_id", user_id).execute()
        liked = False
    else:
        client.table("app_comment_likes").insert({"comment_id": comment_id, "user_id": user_id}).execute()
        liked = True

    row_resp = client.table("app_comments").select("*").eq("id", comment_id).limit(1).execute()
    row = (row_resp.data or [None])[0]
    if not row:
        raise RuntimeError("Comment not found.")

    likes_count = int(
        (
            client.table("app_comment_likes")
            .select("id", count="exact")
            .eq("comment_id", comment_id)
            .execute()
        ).count
        or 0
    )
    updated = client.table("app_comments").update({"likes_count": likes_count}).eq("id", comment_id).execute()
    updated_row = (updated.data or [row])[0]
    return _to_item(updated_row, liked_by_me=liked, liked_by_admin=False)
