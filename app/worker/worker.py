"""Queue worker: drains the Service Bus queue and writes each message to the log.

- Service Bus auth: user-assigned managed identity (AZURE_CLIENT_ID), no connection string.
- AI_API_KEY: injected by Container Apps from a Key Vault *reference* that is resolved
  with the same managed identity. The code never sees Key Vault credentials and never
  logs the value, only a short fingerprint so rotation can be verified.
- Persistence (bonus): each message is upserted into Cosmos DB with id = message_id,
  so a Service Bus redelivery overwrites instead of duplicating. Also Entra ID only.
- Scaling is external (KEDA on queue length, min replicas = 0), so the process just
  loops until SIGTERM and then finishes the in-flight batch.
"""

import hashlib
import json
import logging
import os
import signal
import sys

from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient

SERVICEBUS_FQDN = os.environ["SERVICEBUS_FQDN"]
SERVICEBUS_QUEUE = os.environ["SERVICEBUS_QUEUE"]
AI_API_KEY = os.environ.get("AI_API_KEY", "")
BATCH_SIZE = int(os.getenv("BATCH_SIZE", "10"))
COSMOS_ENDPOINT = os.getenv("COSMOS_ENDPOINT")  # optional: persistence is skipped if unset
COSMOS_DATABASE = os.getenv("COSMOS_DATABASE", "agent-platform")
COSMOS_CONTAINER = os.getenv("COSMOS_CONTAINER", "messages")

logging.basicConfig(
    stream=sys.stdout,
    level=os.getenv("LOG_LEVEL", "INFO"),
    format='{"ts":"%(asctime)s","level":"%(levelname)s","component":"worker","msg":%(message)s}',
)
logging.getLogger("azure").setLevel(logging.WARNING)
log = logging.getLogger("worker")

_running = True


def jlog(level: int, **fields) -> None:
    log.log(level, json.dumps(fields, default=str))


def _stop(signum, _frame) -> None:
    global _running
    _running = False
    jlog(logging.INFO, event="shutdown_requested", signal=signum)


def process(body: dict, store) -> None:
    """Stand-in for the real AI agent call."""
    payload = body.get("payload", {})
    if isinstance(payload, dict) and payload.get("simulate_failure"):
        # Lets you exercise the retry -> dead-letter -> alert path end to end.
        raise RuntimeError("simulated processing failure")
    if store is not None:
        store.upsert_item({"id": body["message_id"], **body})
    jlog(
        logging.INFO,
        event="message_processed",
        message_id=body.get("message_id"),
        persisted=store is not None,
        payload=payload,
    )


def main() -> None:
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    if AI_API_KEY:
        fingerprint = hashlib.sha256(AI_API_KEY.encode()).hexdigest()[:8]
        jlog(logging.INFO, event="secret_loaded", name="AI_API_KEY", source="key_vault", sha256_prefix=fingerprint)
    else:
        jlog(logging.WARNING, event="secret_missing", name="AI_API_KEY")

    credential = DefaultAzureCredential()
    store = None
    if COSMOS_ENDPOINT:
        store = (
            CosmosClient(COSMOS_ENDPOINT, credential=credential)
            .get_database_client(COSMOS_DATABASE)
            .get_container_client(COSMOS_CONTAINER)
        )

    with ServiceBusClient(fully_qualified_namespace=SERVICEBUS_FQDN, credential=credential) as client:
        with client.get_queue_receiver(queue_name=SERVICEBUS_QUEUE) as receiver:
            jlog(logging.INFO, event="listening", namespace=SERVICEBUS_FQDN, queue=SERVICEBUS_QUEUE)
            while _running:
                batch = receiver.receive_messages(max_message_count=BATCH_SIZE, max_wait_time=5)
                for msg in batch:
                    try:
                        body = json.loads(str(msg))
                        process(body, store)
                        receiver.complete_message(msg)
                    except json.JSONDecodeError:
                        # Poison message: retrying will never help, dead-letter immediately.
                        receiver.dead_letter_message(msg, reason="InvalidJson", error_description="body is not JSON")
                        jlog(logging.ERROR, event="dead_lettered", message_id=msg.message_id, reason="InvalidJson")
                    except Exception as exc:  # noqa: BLE001 - any failure goes back to the queue
                        # Abandon -> redelivery; after max_delivery_count Service Bus moves it to the DLQ.
                        receiver.abandon_message(msg)
                        jlog(
                            logging.ERROR,
                            event="processing_failed",
                            message_id=msg.message_id,
                            delivery_count=msg.delivery_count,
                            error=str(exc),
                        )
    credential.close()
    jlog(logging.INFO, event="stopped")


if __name__ == "__main__":
    main()
