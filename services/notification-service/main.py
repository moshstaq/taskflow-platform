import asyncio
import json
import logging
import os
from contextlib import asynccontextmanager

from azure.identity.aio import DefaultAzureCredential
from azure.servicebus.aio import ServiceBusClient
from fastapi import FastAPI

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("notification-service")

SERVICEBUS_FQDN = os.environ["SERVICEBUS_FQDN"]
SERVICEBUS_TOPIC = os.environ["SERVICEBUS_TOPIC"]
SERVICEBUS_SUBSCRIPTION = os.environ["SERVICEBUS_SUBSCRIPTION"]

seen_task_ids = set()

async def consume(client: ServiceBusClient):
    async with client.get_subcription_receiver(
        topic_name=SERVICEBUS_TOPIC,
        subcription_name=SERVICEBUS_SUBSCRIPTION,
        max_wait_time=5,
    ) as receiver:
        logger.info("Listening on %s/%s", SERVICEBUS_TOPIC, SERVICEBUS_SUBSCRIPTION)
        while True:
            messages = await receiver.receive_messages(max_message_count=10, max_wait_time=5)
            for message in messages:
                task_id = message.message_id
                if task_id in seen_task_ids:
                    logger.warning("Duplicate delivery of %s, skipping work", task_id)
                else:
                    body = json.loads(str(message))
                    logger.info("Notifying for task %s: %s", task_id, body)
                    seen_task_ids.add(task_id)
                await receiver.complete_message(message)

@asynccontextmanager
async def lifespan(app: FastAPI):
    credential = DefaultAzureCredential()
    client = ServiceBusClient(
        fully_qualified_namespace=SERVICEBUS_FQDN,
        credential=credential,
    )
    task = asyncio.create_task(consume(client))

    yield

    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass
    await client.close()
    await credential.close()
    logger.info("Consumer stopped")

app = FastAPI(title="notfication-service", lifespan=lifespan)

@app.get("/health")
def health():
    return {"status": "ok", "service": "notification-service"}