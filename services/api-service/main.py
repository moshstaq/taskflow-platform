import os
import logging
import uuid
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, HTTPException

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("api-service")

PROCESSOR_URL = os.getenv("PROCESSPR_URL", "http://processor-service")

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.http = httpx.AsyncClient(base_url=PROCESSOR_URL, timeout=5.0)
    logger.info("HTTP client ready for %s", PROCESSOR_URL)

    yield

    await app.state.http.aclose()


app = FastAPI(title="api-service", lifespan=lifespan)


@app.get("/health")
def health():
    return {"status": "ok", "service": "api-service"}

@app.post("/task", status_code=202)
async def create_task(task: dict):
    task_id = str(uuid.uuid4())
    payload = {"task_id": task_id, **task}

    try:
        response = await app.state.http.post("/process", json=payload)
        response.raise_for_status()
    except httpx.HTTPError:
        logger.exception("Processor call failed for task %s", task_id)
        raise HTTPException(status_code=502, detail="processor unavailable")

    logger.info("Task %s accepted", task_id)
    return {"status": "accepted", "task_id": task_id}