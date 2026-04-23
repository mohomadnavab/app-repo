# =============================================================================
# Multi-stage build — keeps final image minimal and secure
# FIX CRITICAL-06: Removed --build-arg APP_VERSION (no ARG instruction existed)
#                  APP_VERSION is set at runtime via Kubernetes env var
# =============================================================================

# ---- Build stage: install dependencies ----
FROM python:3.12-slim AS builder

WORKDIR /app

COPY src/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Runtime stage ----
FROM python:3.12-slim

# Security: non-root user
RUN addgroup --system appgroup && \
    adduser --system --ingroup appgroup --no-create-home appuser

WORKDIR /app

# Copy installed Python packages
COPY --from=builder /install /usr/local

# Copy application source only
COPY src/app.py .

# Switch to non-root
USER appuser

EXPOSE 8080

# Production WSGI server — workers tuned for a 2-core container (2*cores+1)
CMD ["gunicorn", \
     "--bind", "0.0.0.0:8080", \
     "--workers", "2", \
     "--timeout", "30", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "app:app"]
