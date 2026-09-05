# M17-E — Account Recovery & User Lifecycle
Password recovery is separate from invitation onboarding and Director-controlled activation status.

Security contract:
- 48-byte URL-safe reset token; SHA-256 digest only in PostgreSQL.
- 60-minute expiry by default; single-use; row-lock consumption.
- Generic forgot-password response prevents account enumeration.
- Inactive accounts cannot recover and recovery never reactivates them.
- Password reset revokes all sessions.
- Signed-in password change keeps the current session and revokes other sessions.
- Deactivation revokes sessions and outstanding reset tokens.
- Existing Argon2id hashing and M17-D 10-character password policy remain authoritative.
- Email delivery reuses the M17-D log/SMTP adapter.

Configuration:
- PASSWORD_RESET_TTL_MINUTES=60
- PASSWORD_RESET_RESEND_SECONDS=60

Routes:
- GET/POST /forgot-password
- GET/POST /reset-password
- POST /account/change-password

Validation adds regular domain #30: Account Recovery & User Lifecycle.
