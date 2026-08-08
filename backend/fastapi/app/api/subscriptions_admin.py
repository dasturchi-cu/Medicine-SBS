from fastapi import APIRouter, Depends, Header, HTTPException, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.subscriptions_admin import SubscriptionsOverviewResponse
from ..services.subscriptions_admin import get_subscriptions_overview, list_purchases_admin, revoke_purchase_admin

router = APIRouter(prefix="/subscriptions", tags=["subscriptions"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> None:
    if not settings.admin_api_key:
        return
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")


@router.get("/overview", response_model=SubscriptionsOverviewResponse)
def get_overview(_: None = Depends(_require_admin_key)):
    return get_subscriptions_overview(get_supabase_client())


@router.get("/purchases")
def get_purchases(search: str = "", _: None = Depends(_require_admin_key)):
    return list_purchases_admin(get_supabase_client(), query=search)


@router.delete("/purchases/{entitlement_id}", status_code=status.HTTP_200_OK)
def remove_purchase(entitlement_id: str, _: None = Depends(_require_admin_key)):
    return revoke_purchase_admin(get_supabase_client(), entitlement_id=entitlement_id)
