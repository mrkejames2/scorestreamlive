from __future__ import annotations
import os, uuid
from pathlib import Path
from typing import Optional
from fastapi import UploadFile
from app.config import settings

ALLOWED_CONTENT_TYPES={"image/png","image/jpeg","image/webp"}
EXTENSION_BY_FORMAT={"png":".png","jpeg":".jpg","webp":".webp"}

class SponsorArtworkStorageError(ValueError): pass
class SponsorArtworkTooLargeError(SponsorArtworkStorageError): pass
class SponsorArtworkUnsupportedTypeError(SponsorArtworkStorageError): pass

def storage_dir()->Path: return Path(settings.SPONSOR_ARTWORK_STORAGE_DIR).resolve()
def ensure_storage_dir()->Path:
    d=storage_dir(); d.mkdir(parents=True,exist_ok=True); return d
def detect_image_format(data:bytes)->Optional[str]:
    if data.startswith(b"\x89PNG\r\n\x1a\n"): return "png"
    if len(data)>=3 and data[:3]==b"\xff\xd8\xff": return "jpeg"
    if len(data)>=12 and data[:4]==b"RIFF" and data[8:12]==b"WEBP": return "webp"
    return None
def validate_uploaded_artwork(*,data:bytes,declared_content_type:Optional[str])->str:
    if not data: raise SponsorArtworkUnsupportedTypeError("Sponsor artwork file is empty")
    if len(data)>settings.SPONSOR_ARTWORK_MAX_BYTES: raise SponsorArtworkTooLargeError(f"Sponsor artwork exceeds the {settings.SPONSOR_ARTWORK_MAX_BYTES}-byte limit")
    detected=detect_image_format(data)
    if detected is None: raise SponsorArtworkUnsupportedTypeError("Sponsor artwork must be PNG, JPEG, or WebP")
    expected={"png":"image/png","jpeg":"image/jpeg","webp":"image/webp"}[detected]
    if declared_content_type and declared_content_type not in ALLOWED_CONTENT_TYPES: raise SponsorArtworkUnsupportedTypeError("Sponsor artwork content type must be image/png, image/jpeg, or image/webp")
    if declared_content_type and declared_content_type!=expected: raise SponsorArtworkUnsupportedTypeError("Sponsor artwork content type does not match the uploaded image")
    return detected
async def save_sponsor_artwork(*,club_id:uuid.UUID,upload:UploadFile)->str:
    data=await upload.read(settings.SPONSOR_ARTWORK_MAX_BYTES+1)
    detected=validate_uploaded_artwork(data=data,declared_content_type=upload.content_type)
    filename=f"{club_id}-{uuid.uuid4().hex}{EXTENSION_BY_FORMAT[detected]}"
    d=ensure_storage_dir(); final=d/filename; temp=d/f".{filename}.tmp"
    try: temp.write_bytes(data); os.replace(temp,final)
    finally:
        if temp.exists(): temp.unlink(missing_ok=True)
    return filename
def path_for_filename(filename:str)->Path:
    if not filename or Path(filename).name!=filename: raise FileNotFoundError(filename)
    p=storage_dir()/filename
    if not p.is_file(): raise FileNotFoundError(filename)
    return p
def filename_from_artwork_url(url:Optional[str])->Optional[str]:
    prefix="/api/sponsor-assets/"
    if not url or not url.startswith(prefix): return None
    filename=url.removeprefix(prefix)
    return filename if Path(filename).name==filename else None
def delete_filename(filename:Optional[str])->None:
    if not filename or Path(filename).name!=filename: return
    (storage_dir()/filename).unlink(missing_ok=True)
