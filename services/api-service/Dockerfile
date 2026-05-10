# Multi-stage build placeholder for api-service.
# Replace with actual build steps for your chosen language and runtime.
# Distroless base is recommended for production — minimal attack surface.

FROM python:3.12-slim

WORKDIR /app

# Non-root user — never run application containers as root.
RUN adduser --disabled-password --gecos "" appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

USER appuser
EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
