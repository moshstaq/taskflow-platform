from fastapi import FastAPI

app = FastAPI(title="notification-service")


@app.get("/health")
def health():
    return {"status": "ok", "service": "notification-service"}

# This service is an async consumer — it has no inbound HTTP business routes.
# In production a background task started via @app.on_event("startup") would
# open a Service Bus receiver using workload identity (DefaultAzureCredential),
# pull messages from the notification-service subscription on the task-events
# topic, and dispatch notifications.
#
# The HTTP server exists solely to serve the /health endpoint so Kubernetes
# liveness and readiness probes have a target.