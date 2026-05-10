import os
from fastapi import FastAPI

app = FastAPI(title="api-service")

# In production this resolves to processor-service via Kubernetes DNS.
# Format: http://<service-name>.<namespace>.svc.cluster.local
# The short form http://processor-service works within the same namespace.
PROCESSOR_URL = os.getenv("PROCESSOR_URL", "http://processor-service")


@app.get("/health")
def health():
    return {"status": "ok", "service": "api-service"}


@app.post("/tasks", status_code=202)
def create_task(task: dict):
    # Stub: in production this calls POST processor-service/process
    # and returns a task ID to the caller.
    return {
        "status": "accepted",
        "message": "task queued for processing",
        "processor_url": PROCESSOR_URL,
    }