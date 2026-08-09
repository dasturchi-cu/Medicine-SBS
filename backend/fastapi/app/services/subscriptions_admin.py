from __future__ import annotations

import logging
from ..neon_client import Client

from ..schemas.subscriptions_admin import (
    CourseBuyerItem,
    CourseSubscriptionItem,
    PurchaseAdminItem,
    PurchasesAdminResponse,
    SubscriptionsOverviewResponse,
)

logger = logging.getLogger(__name__)


def get_subscriptions_overview(client: Client) -> SubscriptionsOverviewResponse:
    try:
        entitlements = (
            client.table("user_entitlements")
            .select("user_id,course_id,created_at")
            .eq("is_active", True)
            .execute()
        ).data or []

        if not entitlements:
            return SubscriptionsOverviewResponse(total_course_sales=0, total_unique_buyers=0, items=[])

        course_ids = list({str(row.get("course_id") or "") for row in entitlements if row.get("course_id")})
        user_ids = list({str(row.get("user_id") or "") for row in entitlements if row.get("user_id")})

        courses_rows = client.table("courses").select("id,title_uz").in_("id", course_ids).execute().data or []
        users_rows = client.table("users").select("id,full_name,phone").in_("id", user_ids).execute().data or []

        course_titles = {str(row.get("id")): str(row.get("title_uz") or "") for row in courses_rows}
        users_map = {
            str(row.get("id")): {
                "name": str(row.get("full_name") or "Foydalanuvchi"),
                "email": str(row.get("phone") or ""),
            }
            for row in users_rows
        }

        grouped: dict[str, list[CourseBuyerItem]] = {}
        for row in entitlements:
            course_id = str(row.get("course_id") or "")
            user_id = str(row.get("user_id") or "")
            if not course_id or not user_id:
                continue
            user_info = users_map.get(user_id, {"name": "Foydalanuvchi", "email": ""})
            grouped.setdefault(course_id, []).append(
                CourseBuyerItem(
                    user_id=user_id,
                    user_name=str(user_info["name"]),
                    user_email=str(user_info["email"]),
                    purchased_at=str(row.get("created_at") or ""),
                )
            )

        items = [
            CourseSubscriptionItem(
                course_id=course_id,
                course_title=course_titles.get(course_id, course_id),
                buyers=buyers,
            )
            for course_id, buyers in grouped.items()
        ]
        items.sort(key=lambda item: len(item.buyers), reverse=True)

        return SubscriptionsOverviewResponse(
            total_course_sales=len(entitlements),
            total_unique_buyers=len({str(row.get("user_id") or "") for row in entitlements}),
            items=items,
        )
    except Exception as error:
        logger.warning("Failed to build subscriptions overview from Supabase: %s", error)
        return SubscriptionsOverviewResponse(total_course_sales=0, total_unique_buyers=0, items=[])


def list_purchases_admin(client: Client, *, query: str = "") -> PurchasesAdminResponse:
    entitlements = (
        client.table("user_entitlements")
        .select("id,user_id,course_id,created_at,is_active")
        .eq("is_active", True)
        .is_("section_id", None)
        .order("created_at", desc=True)
        .execute()
    ).data or []
    if not entitlements:
        return PurchasesAdminResponse(total=0, items=[])

    course_ids = list({str(row.get("course_id") or "") for row in entitlements if row.get("course_id")})
    user_ids = list({str(row.get("user_id") or "") for row in entitlements if row.get("user_id")})
    courses_rows = client.table("courses").select("id,title_uz").in_("id", course_ids).execute().data or []
    users_rows = client.table("users").select("id,full_name,phone").in_("id", user_ids).execute().data or []
    course_titles = {str(row.get("id")): str(row.get("title_uz") or row.get("id") or "") for row in courses_rows}
    users_map = {
        str(row.get("id")): {"name": str(row.get("full_name") or "Foydalanuvchi"), "email": str(row.get("phone") or "")}
        for row in users_rows
    }

    q = query.strip().lower()
    items: list[PurchaseAdminItem] = []
    for row in entitlements:
        user_id = str(row.get("user_id") or "")
        course_id = str(row.get("course_id") or "")
        user_info = users_map.get(user_id, {"name": "Foydalanuvchi", "email": ""})
        item = PurchaseAdminItem(
            entitlement_id=str(row.get("id") or ""),
            user_id=user_id,
            user_name=str(user_info["name"]),
            user_email=str(user_info["email"]),
            course_id=course_id,
            course_title=course_titles.get(course_id, course_id),
            purchased_at=str(row.get("created_at") or ""),
            is_active=bool(row.get("is_active")),
        )
        if q and q not in f"{item.user_name} {item.user_email} {item.course_title} {item.user_id}".lower():
            continue
        items.append(item)
    return PurchasesAdminResponse(total=len(items), items=items)


def revoke_purchase_admin(client: Client, *, entitlement_id: str) -> dict[str, str | bool]:
    row = (
        client.table("user_entitlements")
        .select("id,user_id,course_id,is_active")
        .eq("id", entitlement_id)
        .limit(1)
        .execute()
    ).data or []
    if not row:
        return {"revoked": False, "notification_sent": False, "detail": "Entitlement topilmadi."}
    target = row[0]
    client.table("user_entitlements").update({"is_active": False}).eq("id", entitlement_id).execute()
    user_id = str(target.get("user_id") or "")
    notification_sent = False
    if user_id:
        inserted = (
            client.table("notifications")
            .insert(
                {
                    "title": "Kurs bekor qilindi",
                    "message": "Kurs bekor qilindi. Qayta olish uchun admin bilan bog'laning.",
                    "image_url": "",
                    "created_by": "admin_panel",
                }
            )
            .execute()
        ).data or []
        if inserted:
            notification_id = str(inserted[0].get("id") or "")
            if notification_id:
                client.table("notification_deliveries").insert(
                    {"notification_id": notification_id, "user_id": user_id}
                ).execute()
                notification_sent = True
    try:
        client.table("audit_logs").insert(
            {
                "actor_type": "admin",
                "actor_id": "admin_panel",
                "action": "purchase_revoked",
                "entity_type": "user_entitlements",
                "entity_id": entitlement_id,
                "metadata": {"user_id": user_id, "course_id": str(target.get("course_id") or "")},
            }
        ).execute()
    except Exception as error:  # audit yozuv muhim emas — bekor qilishni buzmasin
        logger.warning("audit_logs insert failed (revoke still ok): %s", error)
    return {"revoked": True, "notification_sent": notification_sent, "detail": "Xarid bekor qilindi."}
