# FastAPI Backend (Supabase)

Real backend slices:
- Notifications + viewed count
- Home slides (admin-managed)
- Tests + questions + attempts -> ranking points

## 1) Setup

1. Copy `.env.example` to `.env`
2. Fill Supabase variables
3. Install deps:

```bash
pip install -r requirements.txt
```

## 2) Run

```bash
uvicorn app.main:app --reload --port 8000
```

## 3) Endpoints

- `GET /health`
- `GET /api/v1/notifications` (admin panel list)
- `POST /api/v1/notifications` (admin sends notification)
- `DELETE /api/v1/notifications/{id}` (admin delete)
- `GET /api/v1/notifications/feed?user_id=...` (app user feed)
- `POST /api/v1/notifications/{id}/view` (mark viewed)
- `GET /api/v1/slides` (app/admin list)
- `POST /api/v1/slides` (admin create)
- `PATCH /api/v1/slides/{id}` (admin edit)
- `DELETE /api/v1/slides/{id}` (admin delete)
- `GET /api/v1/tests` (list tests)
- `POST /api/v1/tests` (admin create test)
- `DELETE /api/v1/tests/{id}` (admin delete test)
- `GET /api/v1/tests/{id}/questions` (list questions)
- `POST /api/v1/tests/{id}/questions` (admin add question)
- `POST /api/v1/tests/{id}/attempts` (app submits attempt)

## 4) Notes

- Admin protection uses `ADMIN_API_KEY` + `x-admin-api-key`.
- Flutter passes `API_BASE_URL` via dart-define.
- Attempt scoring formula: `points = score_percent + duration_minutes * 0.5`.
