"""Structured logging configuration using the Python standard library."""

import json
import logging
import sys
from contextvars import ContextVar
from datetime import datetime, timezone

_request_id: ContextVar[str | None] = ContextVar("request_id", default=None)

_SENSITIVE_EXACT = {
    "authorization", "cookie", "set_cookie", "password", "db_password",
    "smtp_password", "token", "session", "session_token", "auth_token",
    "secret", "client_secret", "api_key",
}
_SENSITIVE_SUFFIXES = (
    "_password", "_token", "_secret", "_cookie", "_authorization",
)


def set_request_id(request_id: str):
    """Bind a request correlation ID to the current async context."""
    return _request_id.set(request_id)


def reset_request_id(token) -> None:
    """Restore the previous correlation context."""
    _request_id.reset(token)


def get_request_id() -> str | None:
    """Return the active request correlation ID, if any."""
    return _request_id.get()


def _is_sensitive_key(key: str) -> bool:
    normalized = key.strip().lower().replace("-", "_")
    return normalized in _SENSITIVE_EXACT or normalized.endswith(_SENSITIVE_SUFFIXES)


class JSONFormatter(logging.Formatter):
    """Format log records as JSON for structured logging."""

    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        request_id = get_request_id()
        if request_id:
            log_data["request_id"] = request_id

        standard_attrs = {
            "name","msg","args","levelname","levelno","pathname","filename",
            "module","exc_info","exc_text","stack_info","lineno","funcName",
            "created","msecs","relativeCreated","thread","threadName",
            "processName","process","message","asctime",
        }
        for key, value in record.__dict__.items():
            if key in standard_attrs or key.startswith("_"):
                continue
            log_data[key] = "[REDACTED]" if _is_sensitive_key(key) else value

        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_data, default=str)


def configure_logging(log_level: str) -> None:
    """Configure the root logger for structured JSON output to stdout."""
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JSONFormatter())
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level.upper())
    root_logger.handlers = []
    root_logger.addHandler(handler)
