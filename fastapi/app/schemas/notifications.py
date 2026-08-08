from datetime import datetime
from pydantic import BaseModel, Field


class NotificationCreate(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    message: str = Field(min_length=1, max_length=1000)
    image_url: str = ""


class NotificationItem(BaseModel):
    id: str
    title: str
    message: str
    image_url: str
    sent_at: datetime
    recipients_count: int
    viewed_count: int
    clicked_count: int


class NotificationListResponse(BaseModel):
    items: list[NotificationItem]


class NotificationCreateResponse(BaseModel):
    item: NotificationItem


class NotificationFeedItem(BaseModel):
    id: str
    title: str
    message: str
    image_url: str
    sent_at: datetime
    viewed: bool


class NotificationFeedResponse(BaseModel):
    items: list[NotificationFeedItem]


class MarkViewedRequest(BaseModel):
    user_id: str


class MarkClickedRequest(BaseModel):
    user_id: str
