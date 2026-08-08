from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from uuid import UUID

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.tests import (
    QuizAttemptCreate,
    QuizAttemptResponse,
    QuizCreate,
    QuizItem,
    QuizListResponse,
    QuizQuestionCreate,
    QuizQuestionItem,
    QuizQuestionUpdate,
    QuizQuestionsResponse,
)
from ..services.tests import add_question, create_attempt, create_quiz, delete_question, delete_quiz, list_questions, list_quizzes, update_question
from ..services.tests import get_quiz

router = APIRouter(prefix="/tests", tags=["tests"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> None:
    if not settings.admin_api_key:
        return
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")


@router.get("", response_model=QuizListResponse)
def get_tests(lesson_id: UUID | None = Query(default=None)):
    lesson_filter = str(lesson_id) if lesson_id else None
    return QuizListResponse(items=list_quizzes(get_supabase_client(), lesson_id=lesson_filter))


@router.get("/{quiz_id}", response_model=QuizItem)
def get_test(quiz_id: str):
    item = get_quiz(get_supabase_client(), quiz_id=quiz_id)
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Test not found.")
    return item


@router.post("", response_model=QuizItem, status_code=status.HTTP_201_CREATED)
def post_test(
    payload: QuizCreate,
    _: None = Depends(_require_admin_key),
):
    return create_quiz(get_supabase_client(), payload)


@router.delete("/{quiz_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_test(
    quiz_id: str,
    _: None = Depends(_require_admin_key),
):
    delete_quiz(get_supabase_client(), quiz_id=quiz_id)


@router.get("/{quiz_id}/questions", response_model=QuizQuestionsResponse)
def get_test_questions(quiz_id: str):
    return QuizQuestionsResponse(items=list_questions(get_supabase_client(), quiz_id=quiz_id))


@router.post("/{quiz_id}/questions", response_model=QuizQuestionItem, status_code=status.HTTP_201_CREATED)
def post_test_question(
    quiz_id: str,
    payload: QuizQuestionCreate,
    _: None = Depends(_require_admin_key),
):
    return add_question(get_supabase_client(), quiz_id=quiz_id, payload=payload)


@router.patch("/questions/{question_id}", response_model=QuizQuestionItem)
def patch_test_question(
    question_id: str,
    payload: QuizQuestionUpdate,
    _: None = Depends(_require_admin_key),
):
    return update_question(get_supabase_client(), question_id=question_id, payload=payload)


@router.delete("/questions/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_test_question(
    question_id: str,
    _: None = Depends(_require_admin_key),
):
    delete_question(get_supabase_client(), question_id=question_id)


@router.post("/{quiz_id}/attempts", response_model=QuizAttemptResponse, status_code=status.HTTP_201_CREATED)
def post_test_attempt(
    quiz_id: str,
    payload: QuizAttemptCreate,
):
    return create_attempt(get_supabase_client(), quiz_id=quiz_id, payload=payload)
