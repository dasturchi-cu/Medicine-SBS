from datetime import datetime

from pydantic import BaseModel, Field


class AppCommentItem(BaseModel):
    id: str
    course_key: str
    user_id: str
    author_name: str
    text: str
    parent_id: str | None = None
    replies_count: int = 0
    likes_count: int
    liked_by_me: bool
    liked_by_admin: bool = False
    created_at: datetime


class AppCommentsResponse(BaseModel):
    items: list[AppCommentItem]


class AddCommentRequest(BaseModel):
    course_key: str = Field(min_length=1)
    user_id: str = Field(min_length=1)
    author_name: str = Field(min_length=1, max_length=120)
    text: str = Field(min_length=1, max_length=2000)
    parent_id: str | None = None


class AddCommentReplyRequest(BaseModel):
    user_id: str = Field(min_length=1)
    author_name: str = Field(min_length=1, max_length=120)
    text: str = Field(min_length=1, max_length=2000)


class ToggleLikeRequest(BaseModel):
    user_id: str = Field(min_length=1)
