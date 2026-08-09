from fastapi import APIRouter, status
from pydantic import BaseModel, Field

from ..db import get_supabase_client
from ..schemas.mobile_catalog import MobileCatalogResponse
from ..services.mobile_catalog import get_mobile_catalog

router = APIRouter(prefix="/mobile", tags=["mobile"])


class AppOpenRequest(BaseModel):
    user_id: str = Field(min_length=1)


@router.get("/courses", response_model=MobileCatalogResponse)
def get_courses():
    return get_mobile_catalog(get_supabase_client())


@router.post("/app-open", status_code=status.HTTP_204_NO_CONTENT)
def post_app_open(payload: AppOpenRequest):
    """Ilova har ochilganda chaqiriladi — app open sonini oshiradi (aktivlik statistikasi)."""
    client = get_supabase_client()
    uid = payload.user_id.strip()
    if not uid:
        return
    try:
        cur = client.table("users").select("app_open_count").eq("id", uid).limit(1).execute().data or []
        n = int((cur[0].get("app_open_count") if cur else 0) or 0)
        client.table("users").update({"app_open_count": n + 1}).eq("id", uid).execute()
    except Exception:
        pass
