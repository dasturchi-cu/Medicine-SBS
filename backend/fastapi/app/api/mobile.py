from fastapi import APIRouter

from ..db import get_supabase_client
from ..schemas.mobile_catalog import MobileCatalogResponse
from ..services.mobile_catalog import get_mobile_catalog

router = APIRouter(prefix="/mobile", tags=["mobile"])


@router.get("/courses", response_model=MobileCatalogResponse)
def get_courses():
    return get_mobile_catalog(get_supabase_client())
