"""Kitob grantlari — admin foydalanuvchiga qulflangan (narxli) kitobni ochib beradi.

`book_grants` jadvali agar bo'lmasa avtomatik yaratiladi (Neon'da migratsiya
alohida yugurtirish shart emas). user_id/book_id text sifatida saqlanadi —
shim uuid cast muammolarini oldini olish uchun.
"""

from __future__ import annotations

from ..neon_client import Client

_ENSURED = False


def _ensure_table(client: Client) -> None:
    global _ENSURED
    if _ENSURED:
        return
    client.execute_sql(
        """
        CREATE TABLE IF NOT EXISTS public.book_grants (
          id bigserial PRIMARY KEY,
          user_id text NOT NULL,
          book_id text NOT NULL,
          is_active boolean NOT NULL DEFAULT true,
          created_at timestamptz NOT NULL DEFAULT now(),
          UNIQUE (user_id, book_id)
        );
        """
    )
    _ENSURED = True


def granted_book_ids(client: Client, *, user_id: str) -> set[str]:
    """Foydalanuvchiga ochilgan (faol) kitob ID'lari."""
    if not user_id:
        return set()
    _ensure_table(client)
    rows = client.execute_sql(
        "SELECT book_id FROM public.book_grants WHERE user_id = %s AND is_active = true",
        [user_id],
    )
    return {str(r.get("book_id")) for r in rows if r.get("book_id")}


def grant_book(client: Client, *, user_id: str, book_id: str) -> None:
    _ensure_table(client)
    client.execute_sql(
        """
        INSERT INTO public.book_grants (user_id, book_id, is_active)
        VALUES (%s, %s, true)
        ON CONFLICT (user_id, book_id) DO UPDATE SET is_active = true
        """,
        [user_id, book_id],
    )


def revoke_book(client: Client, *, user_id: str, book_id: str) -> None:
    _ensure_table(client)
    client.execute_sql(
        "UPDATE public.book_grants SET is_active = false WHERE user_id = %s AND book_id = %s",
        [user_id, book_id],
    )
