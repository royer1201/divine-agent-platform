"""Ingress API: accepts inbound channel messages and enqueues them on Azure Service Bus.

Auth to Service Bus is Microsoft Entra ID via the container app's user-assigned
managed identity (AZURE_CLIENT_ID). There is no connection string anywhere.
"""

import asyncio
import json
import logging
import os
import sys
import uuid
from contextlib import AsyncExitStack, asynccontextmanager
from datetime import datetime, timezone

from azure.identity.aio import DefaultAzureCredential
from azure.servicebus import ServiceBusMessage
from azure.servicebus.aio import ServiceBusClient
from fastapi import FastAPI, HTTPException, Request

SERVICEBUS_FQDN = os.environ["SERVICEBUS_FQDN"]  # e.g. sb-divine-dev-ab12.servicebus.windows.net
SERVICEBUS_QUEUE = os.environ["SERVICEBUS_QUEUE"]
MAX_BODY_BYTES = 256 * 1024  # Service Bus Standard max message size

logging.basicConfig(
    stream=sys.stdout,
    level=os.getenv("LOG_LEVEL", "INFO"),
    format='{"ts":"%(asctime)s","level":"%(levelname)s","component":"api","msg":%(message)s}',
)
# The Azure SDKs are chatty at INFO.
logging.getLogger("azure").setLevel(logging.WARNING)
log = logging.getLogger("api")


def jlog(level: int, **fields) -> None:
    log.log(level, json.dumps(fields, default=str))


@asynccontextmanager
async def lifespan(app: FastAPI):
    # DefaultAzureCredential -> ManagedIdentityCredential in Azure (uses AZURE_CLIENT_ID
    # to pick the user-assigned identity), `az login` credentials on a laptop.
    async with AsyncExitStack() as stack:
        credential = await stack.enter_async_context(DefaultAzureCredential())
        client = await stack.enter_async_context(
            ServiceBusClient(fully_qualified_namespace=SERVICEBUS_FQDN, credential=credential)
        )
        # Open the AMQP link once at startup. A lazily opened sender races when many
        # requests arrive at once on a cold replica ("client_ready_async" on None).
        app.state.sender = await stack.enter_async_context(client.get_queue_sender(queue_name=SERVICEBUS_QUEUE))
        # One link per replica; the SDK handler is not safe for concurrent sends.
        app.state.send_lock = asyncio.Lock()
        jlog(logging.INFO, event="startup", namespace=SERVICEBUS_FQDN, queue=SERVICEBUS_QUEUE)
        yield


app = FastAPI(title="divine-webhook-api", lifespan=lifespan)


@app.get("/health")
async def health() -> dict:
    # Liveness/readiness only: must not depend on Service Bus, otherwise a
    # downstream blip would make the platform restart healthy replicas.
    return {"status": "ok"}


@app.post("/webhook/message", status_code=202)
async def webhook_message(request: Request) -> dict:
    body = await request.body()
    if len(body) > MAX_BODY_BYTES:
        raise HTTPException(status_code=413, detail="payload too large")
    try:
        payload = json.loads(body)
    except (json.JSONDecodeError, UnicodeDecodeError):
        raise HTTPException(status_code=400, detail="body must be valid JSON")

    message_id = str(uuid.uuid4())
    envelope = {
        "message_id": message_id,
        "received_at": datetime.now(timezone.utc).isoformat(),
        "payload": payload,
    }
    message = ServiceBusMessage(json.dumps(envelope), message_id=message_id, content_type="application/json")
    async with request.app.state.send_lock:
        await request.app.state.sender.send_messages(message)
    jlog(logging.INFO, event="enqueued", message_id=message_id)
    return {"status": "queued", "message_id": message_id}
