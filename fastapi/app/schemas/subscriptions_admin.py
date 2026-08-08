from pydantic import BaseModel


class CourseBuyerItem(BaseModel):
    user_id: str
    user_name: str
    user_email: str
    purchased_at: str


class CourseSubscriptionItem(BaseModel):
    course_id: str
    course_title: str
    buyers: list[CourseBuyerItem]


class SubscriptionsOverviewResponse(BaseModel):
    total_course_sales: int
    total_unique_buyers: int
    items: list[CourseSubscriptionItem]


class PurchaseAdminItem(BaseModel):
    entitlement_id: str
    user_id: str
    user_name: str
    user_email: str
    course_id: str
    course_title: str
    purchased_at: str
    is_active: bool


class PurchasesAdminResponse(BaseModel):
    total: int
    items: list[PurchaseAdminItem]
