import json
import logging
import os
import uuid
from contextlib import asynccontextmanager

from azure.identity.aio import DefaultAzureCredential
from azure.core.exceptions import ResourceNotFoundError
from azure.keyvault.secrets.aio import SecretClient
from azure.servicebus import ServiceBusMessage
from azure.servicebus.aio import ServiceBusClient
from azure.servicebus.exceptions import ServiceBusError
from fastapi import FastAPI, HTTPException


logging.basicConfig(level=logging.INFO)
logging.getLogger("azure").setLevel(logging.WARNING)
logger = logging.getLogger("processor-service")

SERVICEBUS_FQDN = os.environ["SERVICEBUS_FQDN"]
SERVICEBUS_TOPIC = os.environ["SERVICEBUS_TOPIC"]
KEYVAULT_URI = os.environ["KEYVAULT_URI"]

@asynccontextmanager
async def lifespan(app: FastAPI):
    credential = DefaultAzureCredential()
    client = ServiceBusClient(
        fully_qualified_namespace=SERVICEBUS_FQDN,
        credential=credential,
    )
    sender = client.get_topic_sender(topic_name=SERVICEBUS_TOPIC)

    # Azure SDK logs AMQP state transitions and HTTP headers at INFO, which buries service logs. Raise to WARNING here; lower temporarily when debugging the credential chain or connection setup.

    app.state.credential = credential
    app.state.client = client
    app.state.sender = sender
    logger.info("Sender ready for topic %s on %s", SERVICEBUS_TOPIC, SERVICEBUS_FQDN)

    secret_client = SecretClient(vault_url=KEYVAULT_URI, credential=credential)
    try:
        await secret_client.get_secret("taskfloe-probe")
        logger.info("Key vault path verified: secret read from %s", KEYVAULT_URI)
    except ResourceNotFoundError:
        logger.info(
            "Key Vault path verified: reached %s and authorised, no probe secret present",
            KEYVAULT_URI,
        )
    finally:
        await secret_client.close()

    yield

    await sender.close()
    await client.close()
    await credential.close()
    logger.info("Service Bus Connections closed")

app = FastAPI(title="processor-service", lifespan=lifespan)

@app.get("/health")
def health():
    return {"status": "ok", "service": "processor-service"}

@app.post("/process", status_code=202)
async def process_task(task: dict):
    task_id = str(task.get("task_id") or uuid.uuid4())

    message = ServiceBusMessage(
        json.dumps({"task_id": task_id, "task": task}),
        message_id=task_id,
        content_type="application/json",
    )

    try:
        await app.state.sender.send_messages(message)
    except ServiceBusError:
        logger.exception("Failed to publish task %s", task_id)
        raise HTTPException(status_code=503, detail="Could not publish task")
    logger.info("Published task %s", task_id)
    return {"status": "accepted", "task_id": task_id}