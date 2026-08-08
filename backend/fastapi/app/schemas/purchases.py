from datetime import datetime

from pydantic import BaseModel, Field


class PurchaseCreateRequest(BaseModel):
    user_id: str = Field(min_length=1)
    course_id: str | None = None
    section_id: str | None = None
    amount_uzs: float = Field(default=0, ge=0)
    provider: str = "manual"


class UserEntitlementItem(BaseModel):
    id: str
    user_id: str
    course_id: str | None
    section_id: str | None
    is_active: bool
    created_at: datetime


class UserEntitlementsResponse(BaseModel):
    items: list[UserEntitlementItem]
