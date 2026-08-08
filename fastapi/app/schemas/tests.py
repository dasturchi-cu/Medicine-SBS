from datetime import datetime

from pydantic import BaseModel, Field


class QuizCreate(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    description: str = ""
    course_id: str | None = None
    section_id: str | None = None
    lesson_id: str | None = None
    estimated_minutes: int = Field(default=10, ge=1, le=600)


class QuizQuestionCreate(BaseModel):
    question_text: str = Field(min_length=1, max_length=500)
    option_a: str = Field(min_length=1, max_length=250)
    option_b: str = Field(min_length=1, max_length=250)
    option_c: str = Field(min_length=1, max_length=250)
    option_d: str = Field(min_length=1, max_length=250)
    correct_option: str = Field(pattern="^[ABCD]$")
    order_no: int = Field(default=1, ge=1)


class QuizQuestionUpdate(BaseModel):
    question_text: str | None = Field(default=None, min_length=1, max_length=500)
    option_a: str | None = Field(default=None, min_length=1, max_length=250)
    option_b: str | None = Field(default=None, min_length=1, max_length=250)
    option_c: str | None = Field(default=None, min_length=1, max_length=250)
    option_d: str | None = Field(default=None, min_length=1, max_length=250)
    correct_option: str | None = Field(default=None, pattern="^[ABCD]$")
    order_no: int | None = Field(default=None, ge=1)


class QuizItem(BaseModel):
    id: str
    title: str
    description: str
    course_id: str | None
    section_id: str | None
    lesson_id: str | None
    estimated_minutes: int
    is_active: bool
    question_count: int
    created_at: datetime


class QuizQuestionItem(BaseModel):
    id: str
    quiz_id: str
    question_text: str
    option_a: str
    option_b: str
    option_c: str
    option_d: str
    correct_option: str
    order_no: int


class QuizListResponse(BaseModel):
    items: list[QuizItem]


class QuizQuestionsResponse(BaseModel):
    items: list[QuizQuestionItem]


class QuizAttemptCreate(BaseModel):
    user_id: str = Field(min_length=1)
    score_percent: float = Field(ge=0, le=100)
    correct_count: int = Field(ge=0)
    total_questions: int = Field(ge=0)
    duration_minutes: float = Field(ge=0, le=5000)


class QuizAttemptResponse(BaseModel):
    points_added: float
    total_score: float
    quiz_minutes: float
