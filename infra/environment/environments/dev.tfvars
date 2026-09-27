# Non-secret, environment-specific settings only. Identifiers that depend on the
# bootstrap run (acr_name) and the alert recipient come from GitHub variables
# (TF_VAR_acr_name, TF_VAR_alert_email); image_tag is the commit SHA.
environment = "dev"

servicebus_sku           = "Standard"
queue_max_delivery_count = 5

api_min_replicas            = 0
api_max_replicas            = 3
worker_max_replicas         = 5
worker_messages_per_replica = 5

key_vault_purge_protection = false
log_retention_days         = 30
log_daily_quota_gb         = 1
