"""Public Team logo file delivery."""

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import FileResponse

from app.services.team_logo_storage import path_for_filename


router = APIRouter(prefix="/api/team-logos", tags=["team-logos"])


@router.get("/{filename}")
async def retrieve_logo(filename: str):
    """Serve a stored Team logo."""
    try:
        path = path_for_filename(filename)
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team logo not found",
        )

    return FileResponse(
        path,
        headers={
            "Cache-Control": "public, max-age=31536000, immutable",
        },
    )
