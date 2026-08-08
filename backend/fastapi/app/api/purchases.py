from fastapi import APIRouter, Query, status

from ..db import get_supabase_client
from ..schemas.purchases import PurchaseCreateRequest, UserEntitlementItem, UserEntitlementsResponse
from ..services.purchases import create_purchase, list_user_entitlements

router = APIRouter(prefix="/purchases", tags=["purchases"])


@router.post("", response_model=UserEntitlementItem, status_code=status.HTTP_201_CREATED)
def post_purchase(payload: PurchaseCreateRequest):
    return create_purchase(get_supabase_client(), payload)


@router.get("/user", response_model=UserEntitlementsResponse)
def get_user_purchases(user_id: str = Query(min_length=1)):
    return UserEntitlementsResponse(items=list_user_entitlements(get_supabase_client(), user_id=user_id))
