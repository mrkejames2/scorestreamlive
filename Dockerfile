# syntax=docker/dockerfile:1
FROM python:3.13-slim

# Prevent Python from writing .pyc files and buffering stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_HOME=/home/appuser/app

# Create a non-root user with a home directory
RUN useradd --create-home appuser

# Set working directory
WORKDIR ${APP_HOME}

# Install dependencies as root, then fix ownership
COPY --chown=appuser:appuser requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code, Alembic configuration, static assets, and entrypoint
COPY --chown=appuser:appuser app/ ./app/
COPY --chown=appuser:appuser alembic/ ./alembic/
COPY --chown=appuser:appuser alembic.ini .
COPY --chown=appuser:appuser static/ ./static/
COPY --chown=appuser:appuser entrypoint.sh .
COPY --chown=appuser:appuser templates/ ./templates/

# Prepare writable Team-logo storage before switching to non-root runtime.
RUN mkdir -p ./static/uploads/team-logos && \
    chown -R appuser:appuser ./static/uploads

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Switch to non-root user for runtime security
USER appuser

# Expose the Uvicorn port
EXPOSE 8000

# Container health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health/live')"

# Enable graceful shutdown on SIGTERM
STOPSIGNAL SIGTERM

# Start via entrypoint script (migrations + server)
CMD ["./entrypoint.sh"]
