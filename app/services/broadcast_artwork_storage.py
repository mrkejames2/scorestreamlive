from __future__ import annotations
import os,uuid
from pathlib import Path
from fastapi import UploadFile
from app.config import settings
ALLOWED={"image/png":"png","image/jpeg":"jpg","image/webp":"webp"}
class BroadcastArtworkTooLargeError(ValueError):pass
class BroadcastArtworkUnsupportedTypeError(ValueError):pass
def storage_dir():return Path(settings.GAME_INTRO_STORAGE_DIR).resolve()
def ensure_storage_dir():d=storage_dir();d.mkdir(parents=True,exist_ok=True);return d
def _format(data):
    if data.startswith(b"\x89PNG\r\n\x1a\n"):return "image/png"
    if data[:3]==b"\xff\xd8\xff":return "image/jpeg"
    if len(data)>=12 and data[:4]==b"RIFF" and data[8:12]==b"WEBP":return "image/webp"
async def save_broadcast_artwork(*,club_id,upload:UploadFile):
    data=await upload.read(settings.GAME_INTRO_MAX_BYTES+1)
    if len(data)>settings.GAME_INTRO_MAX_BYTES:raise BroadcastArtworkTooLargeError("Broadcast artwork exceeds the upload limit")
    fmt=_format(data)
    if not data or fmt not in ALLOWED or upload.content_type!=fmt:raise BroadcastArtworkUnsupportedTypeError("Broadcast artwork must be PNG, JPEG, or WebP and match its content type")
    name=f"{club_id}-broadcast-{uuid.uuid4().hex}.{ALLOWED[fmt]}";d=ensure_storage_dir();tmp=d/f".{name}.tmp";final=d/name
    try:tmp.write_bytes(data);os.replace(tmp,final)
    finally:
        if tmp.exists():tmp.unlink(missing_ok=True)
    return name
def path_for_filename(n):
    if not n or Path(n).name!=n:raise FileNotFoundError(n)
    p=storage_dir()/n
    if not p.is_file():raise FileNotFoundError(n)
    return p
def filename_from_url(url):
    pre="/api/broadcast-artwork-assets/"
    if not url or not url.startswith(pre):return None
    n=url[len(pre):];return n if Path(n).name==n else None
def delete_filename(n):
    if n and Path(n).name==n:(storage_dir()/n).unlink(missing_ok=True)
