from __future__ import annotations

import re
from datetime import datetime
from typing import Any

from ..neon_client import Client

from ..schemas.admin_comments import AdminCommentItem

_UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
_CHUNK = 80


def _chunks(keys: list[str]) -> list[list[str]]:
    return [keys[i : i + _CHUNK] for i in range(0, len(keys), _CHUNK)]


def _resolve_course_titles(client: Client, keys: list[str]) -> dict[str, str]:
    """course_key / course_id → kurs nomi yoki banner sarlavhasi.

    UUID bo'lmagan kalitlar (masalan "test") `courses.id` bilan `.in_` ga aralashsa butun so'rov xato/yo'q bo'lishi mumkin —
    shuning uchun UUID va matn kalitlar ajratiladi.
    """
    out: dict[str, str] = {}
    uniq = list(dict.fromkeys(k.strip() for k in keys if (k or "").strip()))
    if not uniq:
        return out

    uuid_keys = [k for k in uniq if _UUID_RE.match(k)]
    text_keys = [k for k in uniq if k not in uuid_keys]

    for batch in _chunks(uuid_keys):
        courses_rows = client.table("courses").select("id,title_uz").in_("id", batch).execute().data or []
        for row in courses_rows:
            kid = str(row.get("id") or "")
            title = str(row.get("title_uz") or "").strip()
            if kid and title:
                out[kid] = title

    for tk in text_keys:
        rows = client.table("courses").select("id,title_uz").eq("title_uz", tk).limit(1).execute().data or []
        if rows:
            title = str(rows[0].get("title_uz") or "").strip()
            if title:
                out[tk] = title

    missing_uuid = [k for k in uuid_keys if k not in out]
    for batch in _chunks(missing_uuid):
        banners_by_id = (
            client.table("course_banners").select("id,title,course_id").in_("id", batch).execute().data or []
        )
        for row in banners_by_id:
            bid = str(row.get("id") or "")
            title = str(row.get("title") or "").strip()
            if bid and title:
                out[bid] = title

    missing2_uuid = [k for k in missing_uuid if k not in out]
    for batch in _chunks(missing2_uuid):
        banners_by_course = (
            client.table("course_banners")
            .select("id,title,course_id")
            .in_("course_id", batch)
            .execute()
            .data
            or []
        )
        for row in banners_by_course:
            cid = str(row.get("course_id") or "")
            title = str(row.get("title") or "").strip()
            if cid and title and cid not in out:
                out[cid] = title

    return out


def _course_title_display(course_key: str, resolved_title: str) -> str:
    """Nom topilmasa uzun UUID o‘rniga qisqa matn; slug kalitlarini qoldiramiz."""
    resolved = (resolved_title or "").strip()
    if resolved:
        return resolved
    ck = (course_key or "").strip()
    if not ck:
        return ""
    if _UUID_RE.match(ck):
        return f"Kurs topilmadi · …{ck[-12:]}"
    return ck


def _resolve_admin_actor(client: Client, configured_admin_user_id: str | None) -> str:
    configured = (configured_admin_user_id or "").strip()
    if configured:
        exists = client.table("users").select("id").eq("id", configured).limit(1).execute().data or []
        if exists:
            return configured
    first_user = client.table("users").select("id").order("created_at", desc=False).limit(1).execute().data or []
    if not first_user:
        raise RuntimeError("Admin amallar uchun users jadvalida hech bo'lmasa bitta user kerak.")
    return str(first_user[0].get("id") or "")


def list_admin_comments(client: Client, *, configured_admin_user_id: str | None = None) -> list[AdminCommentItem]:
    legacy_comments = client.table("comments").select("*").order("created_at", desc=True).limit(500).execute().data or []
    app_comments = client.table("app_comments").select("*").order("created_at", desc=True).limit(500).execute().data or []
    if not legacy_comments and not app_comments:
        return []
    comments = list(legacy_comments) + list(app_comments)
    comments.sort(key=lambda row: str(row.get("created_at") or ""), reverse=True)
    course_keys = [
        str(row.get("course_id") or row.get("course_key") or "").strip()
        for row in comments
        if (row.get("course_id") or row.get("course_key"))
    ]
    title_by_key = _resolve_course_titles(client, course_keys)

    user_ids = list({str(row.get("user_id")) for row in comments if row.get("user_id")})
    users = (
        client.table("users").select("id,full_name,phone").in_("id", user_ids).execute().data
        if user_ids
        else []
    )
    user_map = {
        str(row.get("id")): str(row.get("full_name") or row.get("phone") or row.get("id") or "")
        for row in (users or [])
    }

    admin_user_id = _resolve_admin_actor(client, configured_admin_user_id)
    comment_ids = [str(row.get("id")) for row in comments if row.get("id")]
    liked: set[str] = set()
    if comment_ids:
        admin_reactions = (
            client.table("comment_reactions")
            .select("comment_id")
            .eq("user_id", admin_user_id)
            .in_("comment_id", comment_ids)
            .execute()
        ).data or []
        admin_app_reactions = (
            client.table("app_comment_likes")
            .select("comment_id")
            .eq("user_id", admin_user_id)
            .in_("comment_id", comment_ids)
            .execute()
        ).data or []
        liked = {str(row.get("comment_id")) for row in admin_reactions} | {
            str(row.get("comment_id")) for row in admin_app_reactions
        }

    items: list[AdminCommentItem] = []
    for row in comments:
        ck = str(row.get("course_id") or row.get("course_key") or "").strip()
        items.append(
            AdminCommentItem(
                id=str(row.get("id") or ""),
                course_id=ck,
                course_title=_course_title_display(ck, title_by_key.get(ck, "")),
                user_id=str(row.get("user_id") or ""),
                user_name=str(
                    row.get("author_name")
                    or user_map.get(str(row.get("user_id") or ""), str(row.get("user_id") or ""))
                ),
                text=str(row.get("text") or ""),
                hearts=int(row.get("hearts_count") or row.get("likes_count") or 0),
                parent_id=str(row.get("parent_id")) if row.get("parent_id") else None,
                created_at=str(row.get("created_at") or ""),
                hearted_by_admin=str(row.get("id") or "") in liked,
            )
        )
    return items


def add_admin_reply(client: Client, *, comment_id: str, text: str, configured_admin_user_id: str | None = None) -> AdminCommentItem:
    parent = client.table("comments").select("*").eq("id", comment_id).limit(1).execute().data or []
    parent_source = "comments"
    if not parent:
        parent = client.table("app_comments").select("*").eq("id", comment_id).limit(1).execute().data or []
        parent_source = "app_comments"
    if not parent:
        raise RuntimeError("Izoh topilmadi.")
    parent_row = parent[0]
    admin_user_id = _resolve_admin_actor(client, configured_admin_user_id)
    if parent_source == "comments":
        inserted = (
            client.table("comments")
            .insert(
                {
                    "course_id": parent_row.get("course_id"),
                    "user_id": admin_user_id,
                    "parent_id": comment_id,
                    "text": text.strip(),
                    "hearts_count": 0,
                }
            )
            .execute()
        ).data or []
    else:
        inserted = (
            client.table("app_comments")
            .insert(
                {
                    "course_key": parent_row.get("course_key"),
                    "user_id": admin_user_id,
                    "author_name": "Admin",
                    "text": text.strip(),
                    "likes_count": 0,
                    "parent_id": comment_id,
                }
            )
            .execute()
        ).data or []
    if not inserted:
        raise RuntimeError("Javob qo'shib bo'lmadi.")
    item = inserted[0]
    user_name = client.table("users").select("full_name,phone").eq("id", admin_user_id).limit(1).execute().data or []
    author = str((user_name[0].get("full_name") if user_name else "") or (user_name[0].get("phone") if user_name else "") or "Admin")
    if parent_source == "app_comments":
        replies_count = int(
            (
                client.table("app_comments")
                .select("id", count="exact")
                .eq("parent_id", comment_id)
                .execute()
            ).count
            or 0
        )
        client.table("app_comments").update({"replies_count": replies_count}).eq("id", comment_id).execute()
    ck = str(item.get("course_id") or item.get("course_key") or "").strip()
    titles = _resolve_course_titles(client, [ck]) if ck else {}
    return AdminCommentItem(
        id=str(item.get("id") or ""),
        course_id=ck,
        course_title=_course_title_display(ck, titles.get(ck, "")),
        user_id=admin_user_id,
        user_name=author,
        text=str(item.get("text") or ""),
        hearts=int(item.get("hearts_count") or item.get("likes_count") or 0),
        parent_id=str(item.get("parent_id") or comment_id) if parent_source in {"comments", "app_comments"} else None,
        created_at=str(item.get("created_at") or datetime.utcnow().isoformat()),
        hearted_by_admin=False,
    )


def toggle_admin_heart(client: Client, *, comment_id: str, configured_admin_user_id: str | None = None) -> AdminCommentItem:
    comment_rows = client.table("comments").select("*").eq("id", comment_id).limit(1).execute().data or []
    source = "comments"
    like_table = "comment_reactions"
    like_column = "hearts_count"
    course_column = "course_id"
    if not comment_rows:
        comment_rows = client.table("app_comments").select("*").eq("id", comment_id).limit(1).execute().data or []
        source = "app_comments"
        like_table = "app_comment_likes"
        like_column = "likes_count"
        course_column = "course_key"
    if not comment_rows:
        raise RuntimeError("Izoh topilmadi.")
    comment = comment_rows[0]
    admin_user_id = _resolve_admin_actor(client, configured_admin_user_id)
    existing = (
        client.table(like_table)
        .select("id")
        .eq("comment_id", comment_id)
        .eq("user_id", admin_user_id)
        .limit(1)
        .execute()
    ).data or []
    if existing:
        client.table(like_table).delete().eq("comment_id", comment_id).eq("user_id", admin_user_id).execute()
        delta = -1
        hearted = False
    else:
        client.table(like_table).insert({"comment_id": comment_id, "user_id": admin_user_id}).execute()
        delta = 1
        hearted = True

    next_hearts = max(0, int(comment.get(like_column) or 0) + delta)
    updated = client.table(source).update({like_column: next_hearts}).eq("id", comment_id).execute().data or [comment]
    row = updated[0]
    author = client.table("users").select("full_name,phone").eq("id", row.get("user_id")).limit(1).execute().data or []
    name = str(
        row.get("author_name")
        or (author[0].get("full_name") if author else "")
        or (author[0].get("phone") if author else "")
        or row.get("user_id")
        or ""
    )
    ck = str(row.get(course_column) or "").strip()
    titles = _resolve_course_titles(client, [ck]) if ck else {}
    return AdminCommentItem(
        id=str(row.get("id") or ""),
        course_id=ck,
        course_title=_course_title_display(ck, titles.get(ck, "")),
        user_id=str(row.get("user_id") or ""),
        user_name=name,
        text=str(row.get("text") or ""),
        hearts=int(row.get(like_column) or 0),
        parent_id=str(row.get("parent_id")) if row.get("parent_id") else None,
        created_at=str(row.get("created_at") or ""),
        hearted_by_admin=hearted,
    )


def delete_admin_comment(client: Client, *, comment_id: str) -> None:
    deleted = client.table("comments").delete().eq("id", comment_id).execute().data or []
    if deleted:
        return
    target = client.table("app_comments").select("id,parent_id").eq("id", comment_id).limit(1).execute().data or []
    if not target:
        return
    parent_id = str(target[0].get("parent_id") or "")
    client.table("app_comments").delete().eq("id", comment_id).execute()
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
