from pydantic import BaseModel, Field


class AdminUserItem(BaseModel):
    id: str
    name: str
    email: str
    registration_date: str
    login_count: int
    app_open_count: int
    is_blocked: bool


class AdminUsersResponse(BaseModel):
    items: list[AdminUserItem]


class AdminUserUpdateRequest(BaseModel):
    name: str | None = None
    email: str | None = None
    is_blocked: bool | None = None


class GrantCourseRequest(BaseModel):
    course_id: str = Field(min_length=1)


class UserEntitlementItem(BaseModel):
    id: str
    course_id: str
    course_title: str
    purchased_at: str
    is_active: bool


class UserEntitlementsResponse(BaseModel):
    items: list[UserEntitlementItem]


class UserOverviewMetrics(BaseModel):
    active_courses: int = 0
    total_entitlements: int = 0
    ratings_count: int = 0
    comments_count: int = 0
    likes_given_count: int = 0
    replies_count: int = 0
    watched_lessons_count: int = 0
    completed_lessons_count: int = 0
    watched_seconds_total: int = 0
    purchases_count: int = 0
    paid_total_uzs: float = 0


class UserRecentRatingItem(BaseModel):
    course_id: str
    course_title: str
    stars: int
    created_at: str


class UserRecentCommentItem(BaseModel):
    id: str
    course_key: str
    course_title: str = ""
    lesson_title: str = ""
    text: str
    likes_count: int
    replies_count: int
    created_at: str


class UserProgressItem(BaseModel):
    lesson_id: str
    lesson_title: str = ""
    course_id: str
    course_title: str
    watched_sec: int
    completed: bool
    updated_at: str


class UserOverviewResponse(BaseModel):
    user_id: str
    metrics: UserOverviewMetrics
    recent_ratings: list[UserRecentRatingItem]
    recent_comments: list[UserRecentCommentItem]
    progress_items: list[UserProgressItem]
