from __future__ import annotations
import os,uuid
from pathlib import Path
from typing import Optional
from fastapi import UploadFile
from app.config import settings
ALLOWED_CONTENT_TYPES={"image/png","image/jpeg","image/webp"}; EXTENSION_BY_FORMAT={"png":".png","jpeg":".jpg","webp":".webp"}; FILENAME_MARKER="-thank-you-"
class GameThankYouStorageError(ValueError): pass
class GameThankYouTooLargeError(GameThankYouStorageError): pass
class GameThankYouUnsupportedTypeError(GameThankYouStorageError): pass
def storage_dir()->Path:return Path(settings.GAME_INTRO_STORAGE_DIR).resolve()
def ensure_storage_dir()->Path:
 d=storage_dir();d.mkdir(parents=True,exist_ok=True);return d
def detect_image_format(data:bytes)->Optional[str]:
 if data.startswith(b"\x89PNG\r\n\x1a\n"):return "png"
 if len(data)>=3 and data[:3]==b"\xff\xd8\xff":return "jpeg"
 if len(data)>=12 and data[:4]==b"RIFF" and data[8:12]==b"WEBP":return "webp"
 return None
def validate(data,declared):
 if not data:raise GameThankYouUnsupportedTypeError("Thank You Screen artwork file is empty")
 if len(data)>settings.GAME_INTRO_MAX_BYTES:raise GameThankYouTooLargeError("Thank You Screen artwork exceeds the upload limit")
 fmt=detect_image_format(data);expected={"png":"image/png","jpeg":"image/jpeg","webp":"image/webp"}.get(fmt)
 if not fmt or declared not in ALLOWED_CONTENT_TYPES or declared!=expected:raise GameThankYouUnsupportedTypeError("Thank You Screen artwork must be PNG, JPEG, or WebP and match its content type")
 return fmt
async def save_game_thank_you(*,club_id,game_id,upload:UploadFile)->str:
 data=await upload.read(settings.GAME_INTRO_MAX_BYTES+1);fmt=validate(data,upload.content_type);name=f"{club_id}-{game_id}{FILENAME_MARKER}{uuid.uuid4().hex}{EXTENSION_BY_FORMAT[fmt]}";d=ensure_storage_dir();final=d/name;tmp=d/f".{name}.tmp"
 try:tmp.write_bytes(data);os.replace(tmp,final)
 finally:
  if tmp.exists():tmp.unlink(missing_ok=True)
 return name
def path_for_filename(filename):
 if not filename or Path(filename).name!=filename or FILENAME_MARKER not in filename:raise FileNotFoundError(filename)
 p=storage_dir()/filename
 if not p.is_file():raise FileNotFoundError(filename)
 return p
def filename_from_url(url):
 prefix="/api/game-thank-you-assets/"
 if not url or not url.startswith(prefix):return None
 n=url.removeprefix(prefix);return n if Path(n).name==n and FILENAME_MARKER in n else None
def delete_filename(filename):
 if filename and Path(filename).name==filename and FILENAME_MARKER in filename:(storage_dir()/filename).unlink(missing_ok=True)
