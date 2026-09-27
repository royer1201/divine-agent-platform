environment = "prod"

servicebus_sku           = "Standard"
queue_max_delivery_count = 5

# Keep one warm API replica so inbound WhatsApp/phone webhooks never hit a cold start.
api_min_replicas            = 1
api_max_replicas            = 10
worker_max_replicas         = 20
worker_messages_per_replica = 10

key_vault_purge_protection = true
log_retention_days         = 90
log_daily_quota_gb         = -1
