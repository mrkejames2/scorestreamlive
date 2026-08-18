"""Filesystem-backed Team logo storage for M12-D2."""

from __future__ import annotations

import os
import uuid
from pathlib import Path
from typing import Optional

from fastapi import UploadFile

from app.config import settings


ALLOWED_CONTENT_TYPES = {
    "image/png",
    "image/jpeg",
    "image/webp",
}

EXTENSION_BY_FORMAT = {
    "png": ".png",
    "jpeg": ".jpg",
    "webp": ".webp",
}


class TeamLogoStorageError(ValueError):
    """Base Team logo storage validation error."""


class TeamLogoTooLargeError(TeamLogoStorageError):
    """Raised when an upload exceeds the configured limit."""


class TeamLogoUnsupportedTypeError(TeamLogoStorageError):
    """Raised when an upload is not PNG, JPEG, or WebP."""


def storage_dir() -> Path:
    """Return the configured Team logo storage directory."""
    return Path(settings.TEAM_LOGO_STORAGE_DIR).resolve()


def ensure_storage_dir() -> Path:
    """Create and return the Team logo storage directory."""
    directory = storage_dir()
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def detect_image_format(data: bytes) -> Optional[str]:
    """Detect supported image format from file signature."""
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"

    if len(data) >= 3 and data[:3] == b"\xff\xd8\xff":
        return "jpeg"

    if (
        len(data) >= 12
        and data[:4] == b"RIFF"
        and data[8:12] == b"WEBP"
    ):
        return "webp"

    return None


def validate_uploaded_logo(
    *,
    data: bytes,
    declared_content_type: Optional[str],
) -> str:
    """Validate size/type and return the detected image format."""
    if not data:
        raise TeamLogoUnsupportedTypeError("Team logo file is empty")

    if len(data) > settings.TEAM_LOGO_MAX_BYTES:
        raise TeamLogoTooLargeError(
            f"Team logo exceeds the {settings.TEAM_LOGO_MAX_BYTES}-byte limit"
        )

    detected_format = detect_image_format(data)

    if detected_format is None:
        raise TeamLogoUnsupportedTypeError(
            "Team logo must be PNG, JPEG, or WebP"
        )

    if (
        declared_content_type
        and declared_content_type not in ALLOWED_CONTENT_TYPES
    ):
        raise TeamLogoUnsupportedTypeError(
            "Team logo content type must be image/png, image/jpeg, or image/webp"
        )

    expected_type = {
        "png": "image/png",
        "jpeg": "image/jpeg",
        "webp": "image/webp",
    }[detected_format]

    if (
        declared_content_type
        and declared_content_type != expected_type
    ):
        raise TeamLogoUnsupportedTypeError(
            "Team logo content type does not match the uploaded image"
        )

    return detected_format


async def save_team_logo(
    *,
    team_id: uuid.UUID,
    upload: UploadFile,
) -> str:
    """Validate and atomically persist a Team logo, returning its filename."""
    data = await upload.read(settings.TEAM_LOGO_MAX_BYTES + 1)

    detected_format = validate_uploaded_logo(
        data=data,
        declared_content_type=upload.content_type,
    )

    extension = EXTENSION_BY_FORMAT[detected_format]
    filename = f"{team_id}-{uuid.uuid4().hex}{extension}"

    directory = ensure_storage_dir()
    final_path = directory / filename
    temp_path = directory / f".{filename}.tmp"

    try:
        temp_path.write_bytes(data)
        os.replace(temp_path, final_path)
    finally:
        if temp_path.exists():
            temp_path.unlink(missing_ok=True)

    return filename


def path_for_filename(filename: str) -> Path:
    """Resolve a safe stored logo filename."""
    if not filename or Path(filename).name != filename:
        raise FileNotFoundError(filename)

    path = storage_dir() / filename

    if not path.is_file():
        raise FileNotFoundError(filename)

    return path


def filename_from_logo_url(logo_url: Optional[str]) -> Optional[str]:
    """Extract a local stored filename from a Team logo URL."""
    prefix = "/api/team-logos/"

    if not logo_url or not logo_url.startswith(prefix):
        return None

    filename = logo_url.removeprefix(prefix)

    if Path(filename).name != filename:
        return None

    return filename


def delete_filename(filename: Optional[str]) -> None:
    """Delete a stored logo filename if it exists."""
    if not filename:
        return

    if Path(filename).name != filename:
        return

    path = storage_dir() / filename
    path.unlink(missing_ok=True)
