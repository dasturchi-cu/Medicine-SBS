from functools import lru_cache

from .config import get_settings
from .neon_client import NeonClient, create_neon_client


@lru_cache(maxsize=1)
def get_supabase_client() -> NeonClient:
    """Tarixiy nom saqlangan (mavjud 224 chaqiruv o'zgarmasin) — endi Neon
    Postgres'ga to'g'ridan-to'g'ri ulanadi (Supabase o'rniga)."""
    settings = get_settings()
    if not settings.database_url:
        raise RuntimeError("DATABASE_URL (Neon) sozlanmagan.")
    return create_neon_client(settings.database_url)
