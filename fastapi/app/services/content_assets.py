from __future__ import annotations

from datetime import datetime
from typing import Any

from ..neon_client import Client

from ..schemas.content_assets import (
    BookCategoryCreate,
    BookCategoryItem,
    BookCreate,
    BookItem,
    BookProgressItem,
    SlideProgressItem,
    SlideProgressUpsert,
    BookProgressUpsert,
    BookUpdate,
    LessonAssetCreate,
    LessonAssetItem,
    LessonAssetUpdate,
)


def _to_lesson_asset(row: dict[str, Any]) -> LessonAssetItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    return LessonAssetItem(
        id=str(row.get("id") or ""),
        course_id=str(row.get("course_id")) if row.get("course_id") else None,
        lesson_id=str(row.get("lesson_id")) if row.get("lesson_id") else None,
        title=str(row.get("title") or ""),
        description=str(row.get("description") or ""),
        file_url=str(row.get("file_url") or ""),
        file_type=str(row.get("file_type") or "pdf"),
        preview_image_url=str(row.get("preview_image_url") or ""),
        order_no=int(row.get("order_no") or 1),
        is_active=bool(row.get("is_active")),
        created_at=created,
    )


def _to_book(row: dict[str, Any], *, has_access: bool = True) -> BookItem:
    created_at = row.get("created_at")
    if isinstance(created_at, str):
        created = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
    elif isinstance(created_at, datetime):
        created = created_at
    else:
        created = datetime.utcnow()
    return BookItem(
        id=str(row.get("id") or ""),
        title=str(row.get("title") or ""),
        description=str(row.get("description") or ""),
        cover_image_url=str(row.get("cover_image_url") or ""),
        file_url=str(row.get("file_url") or ""),
        file_mime=str(row.get("file_mime") or "application/pdf"),
        page_count=int(row.get("page_count") or 0),
        price_uzs=float(row.get("price_uzs") or 0),
        author=str(row.get("author") or ""),
        category_id=str(row.get("category_id")) if row.get("category_id") else None,
        category_name=str(row.get("book_categories", {}).get("name"))
        if isinstance(row.get("book_categories"), dict) and row.get("book_categories", {}).get("name")
        else None,
        course_id=str(row.get("course_id")) if row.get("course_id") else None,
        lesson_id=str(row.get("lesson_id")) if row.get("lesson_id") else None,
        is_active=bool(row.get("is_active")),
        created_at=created,
        has_access=has_access,
    )


def list_lesson_assets(client: Client, *, lesson_id: str | None = None, course_id: str | None = None) -> list[LessonAssetItem]:
    query = client.table("lesson_assets").select("*").order("order_no", desc=False)
    if lesson_id:
        query = query.eq("lesson_id", lesson_id)
    if course_id:
        query = query.eq("course_id", course_id)
    rows = query.execute().data or []
    return [_to_lesson_asset(row) for row in rows]


def _next_lesson_asset_order_no(client: Client, *, lesson_id: str) -> int:
    rows = (
        client.table("lesson_assets")
        .select("order_no")
        .eq("lesson_id", lesson_id)
        .order("order_no", desc=True)
        .limit(1)
        .execute()
    ).data or []
    if not rows:
        return 1
    return int(rows[0].get("order_no") or 0) + 1


def _raise_lesson_asset_insert_failure(error: Exception) -> None:
    message = str(error).lower()
    if "foreign key" in message:
        raise RuntimeError(
            "Tanlangan kurs yoki dars bazada topilmadi (ID eskirgan yoki kurs bilan mos kelmaydi)."
        ) from error
    if "duplicate" in message or "unique constraint" in message:
        raise RuntimeError(
            "Bu dars uchun tartib raqami band yoki slayd allaqachon mavjud — sahifani yangilab qayta urinib ko‘ring."
        ) from error
    raise RuntimeError(f"Slayd qo'shib bo'lmadi: {error}") from error


def create_lesson_asset(client: Client, payload: LessonAssetCreate) -> LessonAssetItem:
    raw = payload.model_dump()
    lid = raw.get("lesson_id")
    if lid:
        raw["order_no"] = _next_lesson_asset_order_no(client, lesson_id=str(lid))

    def _insert_row(data: dict[str, Any]) -> LessonAssetItem:
        inserted = client.table("lesson_assets").insert(data).execute()
        row = (inserted.data or [None])[0]
        if not row:
            raise RuntimeError("Slayd saqlanmadi.")
        _mirror_asset_to_lesson_slides(client, row)
        return _to_lesson_asset(row)

    try:
        return _insert_row(raw)
    except Exception as error:
        message = str(error).lower()
        # Backward-compatible fallback when DB migrations are partially applied.
        if "preview_image_url" in message and "column" in message:
            fallback = {k: v for k, v in raw.items() if k != "preview_image_url"}
            try:
                return _insert_row(fallback)
            except Exception as err2:
                _raise_lesson_asset_insert_failure(err2)
        _raise_lesson_asset_insert_failure(error)


def _mirror_asset_to_lesson_slides(client: Client, row: dict[str, Any]) -> None:
    lesson_id = str(row.get("lesson_id") or "")
    if not lesson_id:
        return
    preview_url = str(row.get("preview_image_url") or "")
    if not preview_url:
        return
    try:
        # Keep slideshow view in sync with uploaded lesson assets.
        client.table("lesson_slides").insert(
            {
                "lesson_id": lesson_id,
                "title": str(row.get("title") or ""),
                "body": str(row.get("description") or ""),
                "image_url": preview_url,
                "order_no": int(row.get("order_no") or 1),
                "is_active": bool(row.get("is_active", True)),
            }
        ).execute()
    except Exception:
        # Non-blocking mirror step; lesson asset itself remains source-of-truth.
        return


def update_lesson_asset(client: Client, *, asset_id: str, payload: LessonAssetUpdate) -> LessonAssetItem:
    patch = {k: v for k, v in payload.model_dump().items() if v is not None}
    if not patch:
        raise RuntimeError("Yangilash uchun maydon yo'q.")
    updated = client.table("lesson_assets").update(patch).eq("id", asset_id).execute()
    row = (updated.data or [None])[0]
    if not row:
        raise RuntimeError("Asset topilmadi.")
    return _to_lesson_asset(row)


def delete_lesson_asset(client: Client, *, asset_id: str) -> None:
    client.table("lesson_assets").delete().eq("id", asset_id).execute()


def list_books(client: Client, *, course_id: str | None = None, user_id: str | None = None) -> list[BookItem]:
    query = client.table("book_items").select("*").order("created_at", desc=True)
    if course_id:
        query = query.eq("course_id", course_id)
    rows = query.execute().data or []
    # Kategoriya nomlarini alohida olamiz (PostgREST embed SQL'da yo'q).
    cat_ids = list({str(r.get("category_id")) for r in rows if r.get("category_id")})
    names: dict[str, str] = {}
    if cat_ids:
        cats = client.table("book_categories").select("id,name").in_("id", cat_ids).execute().data or []
        names = {str(c.get("id")): str(c.get("name") or "") for c in cats}
    for r in rows:
        cid = str(r.get("category_id")) if r.get("category_id") else None
        if cid and names.get(cid):
            r["book_categories"] = {"name": names[cid]}
    # Qulf: narx > 0 bo'lsa qulflangan; lekin admin ochib bergan bo'lsa (grant) ochiq.
    granted: set[str] = set()
    if user_id:
        from .book_grants import granted_book_ids

        granted = granted_book_ids(client, user_id=user_id)
    result: list[BookItem] = []
    for row in rows:
        price = float(row.get("price_uzs") or 0)
        book_id = str(row.get("id") or "")
        has_access = price <= 0 or (book_id in granted)
        result.append(_to_book(row, has_access=has_access))
    return result


def _book_insert_payload(payload: BookCreate) -> dict[str, Any]:
    """Bo‘sh nullable FK va None qiymatlarni PostgREST uchun tozalaymiz."""
    data = payload.model_dump(exclude_none=True)
    for fk in ("category_id", "course_id", "lesson_id"):
        if data.get(fk) == "":
            data.pop(fk, None)
    return data


def _raise_book_insert_failure(error: Exception) -> None:
    message = str(error).lower()
    if "foreign key" in message or "violates foreign key" in message:
        raise RuntimeError(
            "Tanlangan kategoriya yoki bog‘langan kurs/dars bazada yo‘q — "
            "kategoriyasiz saqlab ko‘ring yoki yangi kategoriya yarating."
        ) from error
    if "invalid input syntax for type uuid" in message:
        raise RuntimeError(
            "Noto‘g‘ri UUID (masalan bo‘sh kategoriya ID). "
            "Kategoriya nomini yozib qayta urining yoki kategoriyasiz qoldiring."
        ) from error
    if "duplicate" in message or "unique constraint" in message:
        raise RuntimeError(
            "Bu yozuv bilan noyoblik qoidasi buzildi (masalan bir xil kitob)."
        ) from error
    raise RuntimeError(f"Kitob qo'shib bo'lmadi: {error}") from error


def create_book(client: Client, payload: BookCreate) -> BookItem:
    raw = _book_insert_payload(payload)

    def _insert_row(data: dict[str, Any]) -> BookItem:
        inserted = client.table("book_items").insert(data).execute()
        row = (inserted.data or [None])[0]
        if not row:
            raise RuntimeError("Kitob qo'shilmadi.")
        return _to_book(row)

    try:
        return _insert_row(raw)
    except Exception as error:
        message = str(error).lower()
        if "category_id" in message and "column" in message:
            fallback = {k: v for k, v in raw.items() if k != "category_id"}
            try:
                return _insert_row(fallback)
            except Exception as err2:
                _raise_book_insert_failure(err2)
        if "author" in message and "column" in message:
            fallback = {k: v for k, v in raw.items() if k != "author"}
            try:
                return _insert_row(fallback)
            except Exception as err2:
                _raise_book_insert_failure(err2)
        _raise_book_insert_failure(error)


def update_book(client: Client, *, book_id: str, payload: BookUpdate) -> BookItem:
    patch = {k: v for k, v in payload.model_dump().items() if v is not None}
    if not patch:
        raise RuntimeError("Yangilash uchun maydon yo'q.")
    updated = client.table("book_items").update(patch).eq("id", book_id).execute()
    row = (updated.data or [None])[0]
    if not row:
        raise RuntimeError("Kitob topilmadi.")
    return _to_book(row)


def delete_book(client: Client, *, book_id: str) -> None:
    client.table("book_items").delete().eq("id", book_id).execute()


def list_book_categories(client: Client) -> list[BookCategoryItem]:
    rows = client.table("book_categories").select("*").order("name").execute().data or []
    return [
        BookCategoryItem(
            id=str(row.get("id") or ""),
            name=str(row.get("name") or ""),
            slug=str(row.get("slug") or ""),
        )
        for row in rows
    ]


def create_book_category(client: Client, payload: BookCategoryCreate) -> BookCategoryItem:
    try:
        inserted = client.table("book_categories").insert(payload.model_dump()).execute()
        row = (inserted.data or [None])[0]
        if not row:
            raise RuntimeError("Kategoriya qo'shilmadi.")
        return BookCategoryItem(
            id=str(row.get("id") or ""),
            name=str(row.get("name") or ""),
            slug=str(row.get("slug") or ""),
        )
    except Exception as error:
        message = str(error).lower()
        if "duplicate" in message or "unique constraint" in message:
            raise RuntimeError(
                "Bu nom yoki slug bilan kategoriya allaqachon mavjud — boshqa nom kiriting."
            ) from error
        raise RuntimeError(f"Kategoriya qo'shib bo'lmadi: {error}") from error


def upsert_book_progress(client: Client, *, book_id: str, payload: BookProgressUpsert) -> BookProgressItem:
    existing = (
        client.table("book_progress")
        .select("*")
        .eq("book_id", book_id)
        .eq("user_id", payload.user_id)
        .limit(1)
        .execute()
    ).data or []
    page_no = max(payload.page_no, 1)
    progress_percent = min(100.0, max(0.0, payload.progress_percent))
    if existing:
        current = existing[0]
        page_no = max(int(current.get("page_no") or 1), page_no)
        progress_percent = max(float(current.get("progress_percent") or 0), progress_percent)
        updated = (
            client.table("book_progress")
            .update({"page_no": page_no, "progress_percent": progress_percent})
            .eq("book_id", book_id)
            .eq("user_id", payload.user_id)
            .execute()
        ).data or [current]
        row = updated[0]
    else:
        inserted = client.table("book_progress").insert(
            {
                "book_id": book_id,
                "user_id": payload.user_id,
                "page_no": page_no,
                "progress_percent": progress_percent,
            }
        ).execute()
        row = (inserted.data or [None])[0]
        if not row:
            raise RuntimeError("Progress saqlanmadi.")
    updated_at = row.get("updated_at")
    if isinstance(updated_at, str):
        updated_time = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
    elif isinstance(updated_at, datetime):
        updated_time = updated_at
    else:
        updated_time = datetime.utcnow()
    return BookProgressItem(
        book_id=str(row.get("book_id") or book_id),
        user_id=str(row.get("user_id") or payload.user_id),
        page_no=int(row.get("page_no") or 1),
        progress_percent=float(row.get("progress_percent") or 0),
        updated_at=updated_time,
    )


def list_book_progress(client: Client, *, user_id: str) -> list[BookProgressItem]:
    rows = (
        client.table("book_progress")
        .select("*")
        .eq("user_id", user_id)
        .order("updated_at", desc=True)
        .execute()
    ).data or []
    items: list[BookProgressItem] = []
    for row in rows:
        updated_at = row.get("updated_at")
        if isinstance(updated_at, str):
            updated_time = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
        elif isinstance(updated_at, datetime):
            updated_time = updated_at
        else:
            updated_time = datetime.utcnow()
        items.append(
            BookProgressItem(
                book_id=str(row.get("book_id") or ""),
                user_id=str(row.get("user_id") or ""),
                page_no=int(row.get("page_no") or 1),
                progress_percent=float(row.get("progress_percent") or 0),
                updated_at=updated_time,
            )
        )
    return items


def upsert_slide_progress(client: Client, *, lesson_asset_id: str, payload: SlideProgressUpsert) -> SlideProgressItem:
    existing = (
        client.table("slide_progress")
        .select("*")
        .eq("lesson_asset_id", lesson_asset_id)
        .eq("user_id", payload.user_id)
        .limit(1)
        .execute()
    ).data or []
    page_no = max(payload.page_no, 1)
    progress_percent = min(100.0, max(0.0, payload.progress_percent))
    if existing:
        current = existing[0]
        page_no = max(int(current.get("page_no") or 1), page_no)
        progress_percent = max(float(current.get("progress_percent") or 0), progress_percent)
        row = (
            client.table("slide_progress")
            .update({"page_no": page_no, "progress_percent": progress_percent})
            .eq("lesson_asset_id", lesson_asset_id)
            .eq("user_id", payload.user_id)
            .execute()
        ).data or [current]
        record = row[0]
    else:
        inserted = (
            client.table("slide_progress")
            .insert(
                {
                    "lesson_asset_id": lesson_asset_id,
                    "user_id": payload.user_id,
                    "page_no": page_no,
                    "progress_percent": progress_percent,
                }
            )
            .execute()
        )
        record = (inserted.data or [None])[0]
        if not record:
            raise RuntimeError("Slide progress saqlanmadi.")

    updated_at = record.get("updated_at")
    if isinstance(updated_at, str):
        updated_time = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
    elif isinstance(updated_at, datetime):
        updated_time = updated_at
    else:
        updated_time = datetime.utcnow()
    return SlideProgressItem(
        lesson_asset_id=str(record.get("lesson_asset_id") or lesson_asset_id),
        user_id=str(record.get("user_id") or payload.user_id),
        page_no=int(record.get("page_no") or 1),
        progress_percent=float(record.get("progress_percent") or 0),
        updated_at=updated_time,
    )


def list_slide_progress(client: Client, *, user_id: str, lesson_asset_id: str | None = None) -> list[SlideProgressItem]:
    query = client.table("slide_progress").select("*").eq("user_id", user_id).order("updated_at", desc=True)
    if lesson_asset_id:
        query = query.eq("lesson_asset_id", lesson_asset_id)
    rows = query.execute().data or []
    items: list[SlideProgressItem] = []
    for row in rows:
        updated_at = row.get("updated_at")
        if isinstance(updated_at, str):
            updated_time = datetime.fromisoformat(updated_at.replace("Z", "+00:00"))
        elif isinstance(updated_at, datetime):
            updated_time = updated_at
        else:
            updated_time = datetime.utcnow()
        items.append(
            SlideProgressItem(
                lesson_asset_id=str(row.get("lesson_asset_id") or ""),
                user_id=str(row.get("user_id") or ""),
                page_no=int(row.get("page_no") or 1),
                progress_percent=float(row.get("progress_percent") or 0),
                updated_at=updated_time,
            )
        )
    return items
