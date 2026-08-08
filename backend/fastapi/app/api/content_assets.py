from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, Query, UploadFile, status

from ..config import Settings, get_settings
from ..db import get_supabase_client
from ..schemas.content_assets import (
    BookCategoryCreate,
    BookCategoryItem,
    BookCategoriesResponse,
    BookItem,
    BookCreate,
    BookProgressItem,
    BookProgressListResponse,
    BookProgressUpsert,
    BooksResponse,
    BookUpdate,
    LessonAssetCreate,
    LessonAssetItem,
    LessonAssetsResponse,
    LessonAssetUpdate,
    SlideProgressItem,
    SlideProgressListResponse,
    SlideProgressUpsert,
)
from ..services.content_assets import (
    create_book_category,
    create_book,
    create_lesson_asset,
    delete_book,
    delete_lesson_asset,
    list_books,
    list_book_categories,
    list_book_progress,
    list_lesson_assets,
    list_slide_progress,
    update_book,
    update_lesson_asset,
    upsert_book_progress,
    upsert_slide_progress,
)
from ..services.r2_storage import upload_bytes

router = APIRouter(prefix="/content", tags=["content-assets"])


def _require_admin_key(
    settings: Settings = Depends(get_settings),
    x_admin_api_key: str | None = Header(default=None),
) -> None:
    if not settings.admin_api_key:
        return
    if x_admin_api_key != settings.admin_api_key:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin api key.")


@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    folder: str = Form(default="uploads"),
    _: None = Depends(_require_admin_key),
):
    """Admin panel faylni shu yerga yuboradi; backend Cloudflare R2'ga yuklaydi."""
    data = await file.read()
    if not data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Bo'sh fayl.")
    try:
        result = upload_bytes(
            data=data,
            filename=file.filename or "file.bin",
            folder=folder,
            content_type=file.content_type or "application/octet-stream",
        )
    except RuntimeError as error:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(error))
    return {"path": result["path"], "publicUrl": result["url"], "storageBacked": True}


@router.get("/assets", response_model=LessonAssetsResponse)
def get_assets(
    lesson_id: str | None = Query(default=None),
    course_id: str | None = Query(default=None),
):
    return LessonAssetsResponse(items=list_lesson_assets(get_supabase_client(), lesson_id=lesson_id, course_id=course_id))


@router.post("/assets", response_model=LessonAssetItem, status_code=status.HTTP_201_CREATED)
def post_asset(payload: LessonAssetCreate, _: None = Depends(_require_admin_key)):
    try:
        return create_lesson_asset(get_supabase_client(), payload)
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.patch("/assets/{asset_id}", response_model=LessonAssetItem)
def patch_asset(asset_id: str, payload: LessonAssetUpdate, _: None = Depends(_require_admin_key)):
    return update_lesson_asset(get_supabase_client(), asset_id=asset_id, payload=payload)


@router.delete("/assets/{asset_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_asset(asset_id: str, _: None = Depends(_require_admin_key)):
    delete_lesson_asset(get_supabase_client(), asset_id=asset_id)


@router.get("/books", response_model=BooksResponse)
def get_books(course_id: str | None = Query(default=None)):
    return BooksResponse(items=list_books(get_supabase_client(), course_id=course_id))


@router.get("/books/categories", response_model=BookCategoriesResponse)
def get_book_categories():
    return BookCategoriesResponse(items=list_book_categories(get_supabase_client()))


@router.post("/books/categories", response_model=BookCategoryItem, status_code=status.HTTP_201_CREATED)
def post_book_category(payload: BookCategoryCreate, _: None = Depends(_require_admin_key)):
    try:
        return create_book_category(get_supabase_client(), payload)
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/books", response_model=BookItem, status_code=status.HTTP_201_CREATED)
def post_book(payload: BookCreate, _: None = Depends(_require_admin_key)):
    try:
        return create_book(get_supabase_client(), payload)
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.patch("/books/{book_id}", response_model=BookItem)
def patch_book(book_id: str, payload: BookUpdate, _: None = Depends(_require_admin_key)):
    return update_book(get_supabase_client(), book_id=book_id, payload=payload)


@router.delete("/books/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_book(book_id: str, _: None = Depends(_require_admin_key)):
    delete_book(get_supabase_client(), book_id=book_id)


@router.post("/books/{book_id}/progress", response_model=BookProgressItem)
def post_book_progress(book_id: str, payload: BookProgressUpsert):
    return upsert_book_progress(get_supabase_client(), book_id=book_id, payload=payload)


@router.get("/books/progress", response_model=BookProgressListResponse)
def get_books_progress(user_id: str = Query(min_length=1)):
    return BookProgressListResponse(items=list_book_progress(get_supabase_client(), user_id=user_id))


@router.post("/assets/{asset_id}/progress", response_model=SlideProgressItem)
def post_asset_progress(asset_id: str, payload: SlideProgressUpsert):
    return upsert_slide_progress(get_supabase_client(), lesson_asset_id=asset_id, payload=payload)


@router.get("/assets/progress", response_model=SlideProgressListResponse)
def get_assets_progress(
    user_id: str = Query(min_length=1),
    asset_id: str | None = Query(default=None),
):
    return SlideProgressListResponse(
        items=list_slide_progress(get_supabase_client(), user_id=user_id, lesson_asset_id=asset_id)
    )
