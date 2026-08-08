from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "medical-backend"
    api_prefix: str = "/api/v1"
    environment: str = "development"
    frontend_origin: str = "http://localhost:3000"
    # Neon (toza Postgres) ulanish satri — masalan:
    # postgresql://user:pass@ep-xxx.eu-central-1.aws.neon.tech/dbname?sslmode=require
    database_url: str = ""
    # Cloudflare R2 (fayl saqlash — Supabase Storage o'rniga). S3-mos.
    r2_endpoint_url: str = ""          # https://<accountid>.r2.cloudflarestorage.com
    r2_access_key_id: str = ""
    r2_secret_access_key: str = ""
    r2_bucket: str = ""
    r2_public_base_url: str = ""       # https://pub-xxxx.r2.dev yoki custom domain
    # Eski Supabase sozlamalari (endi ishlatilmaydi, mos-kelish uchun qoldirilgan).
    supabase_url: str = ""
    supabase_service_role_key: str = ""
    admin_api_key: str = ""
    admin_user_id: str = ""
    admin_contact_telegram: str = "Mr_Xusanboy"
    # Service account JSON (full string) for Firebase Admin — enables FCM after notifications.create
    firebase_credentials_json: str = ""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
