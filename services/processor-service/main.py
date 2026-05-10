from fastapi import FastAPI

app = FastAPI(title="processor-service")


@app.get("/health")
def health():
    return {"status": "ok", "service": "processor-service"}


@app.post("/process")
def process_task(task: dict):
    # Stub: in production this validates the task payload and publishes
    # an event to the Service Bus task-events topic using workload identity.
    # The notification-service subscription then receives the event.
    return {
        "status": "processed",
        "task": task,
    }