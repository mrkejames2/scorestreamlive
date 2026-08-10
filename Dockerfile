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

# Copy application code with correct ownership
COPY --chown=appuser:appuser app/ ./app/

# Switch to non-root user for runtime security
USER appuser

# Expose the Uvicorn port
EXPOSE 8000

# Container health check using only the standard library
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health/live')"

# Enable graceful shutdown on SIGTERM
STOPSIGNAL SIGTERM

# Start the ASGI server
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]