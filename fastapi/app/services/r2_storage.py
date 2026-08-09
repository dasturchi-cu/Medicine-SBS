"""Cloudflare R2 (S3-mos) fayl yuklash — Supabase Storage o'rniga.

Admin panel faylni backend'ga yuboradi, backend R2'ga yuklaydi va public URL
qaytaradi. R2 kalitlari faqat backend env'da turadi (brauzerga chiqmaydi).
"""

from __future__ import annotations

import uuid
from functools import lru_cache

import boto3
from botocore.config import Config

from ..config import get_settings


@lru_cache(maxsize=1)
def _r2_client():
    s = get_settings()
    if not (s.r2_endpoint_url and s.r2_access_key_id and s.r2_secret_access_key and s.r2_bucket):
        raise RuntimeError("R2 sozlanmagan (R2_ENDPOINT_URL / R2_ACCESS_KEY_ID / R2_SECRET_ACCESS_KEY / R2_BUCKET).")
    return boto3.client(
        "s3",
        endpoint_url=s.r2_endpoint_url,
        aws_access_key_id=s.r2_access_key_id,
        aws_secret_access_key=s.r2_secret_access_key,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )


def upload_bytes(
    *, data: bytes, filename: str, folder: str, content_type: str, key: str | None = None
) -> dict[str, str]:
    """Faylni R2'ga yuklaydi. {"path": key, "url": public_url} qaytaradi.

    `key` berilsa — aynan shu nom bilan saqlanadi (barqaror URL uchun, masalan
    medicine-sbs.apk). Aks holda tasodifiy nom generatsiya qilinadi.
    """
    s = get_settings()
    if key:
        object_key = key.strip("/")
    else:
        ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "bin"
        safe_folder = (folder or "uploads").strip("/")
        object_key = f"{safe_folder}/{uuid.uuid4().hex}.{ext}"
    _r2_client().put_object(
        Bucket=s.r2_bucket,
        Key=object_key,
        Body=data,
        ContentType=content_type or "application/octet-stream",
        CacheControl="public, max-age=31536000",
    )
    base = (s.r2_public_base_url or "").rstrip("/")
    return {"path": object_key, "url": f"{base}/{object_key}"}
