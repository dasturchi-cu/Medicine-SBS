from pydantic import BaseModel, Field


class AdminCommentItem(BaseModel):
    id: str
    course_id: str
    course_title: str = ""
    user_id: str
    user_name: str
    text: str
    hearts: int
    parent_id: str | None
    created_at: str
    hearted_by_admin: bool


class AdminCommentsResponse(BaseModel):
    items: list[AdminCommentItem]


class AdminCommentReplyRequest(BaseModel):
    text: str = Field(min_length=1, max_length=3000)
