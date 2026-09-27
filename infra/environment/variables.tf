variable "project" {
  description = "Must match the bootstrap stack; resource group names are derived from it."
  type        = string
  default     = "divine"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "acr_name" {
  description = "Shared registry created by bootstrap (GitHub variable ACR_NAME)."
  type        = string
}

variable "image_tag" {
  description = "Immutable image tag to deploy; the pipeline passes the git SHA."
  type        = string

  validation {
    condition     = length(var.image_tag) > 0 && var.image_tag != "latest"
    error_message = "Deploy an immutable tag (the git SHA), never 'latest'."
  }
}

variable "alert_email" {
  description = "Recipient of the dead-letter alert. Sensitive so it stays out of plans published to public run logs."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be an email address. In CI it comes from the ALERT_EMAIL secret."
  }
}

# --- Service Bus -----------------------------------------------------------

variable "servicebus_sku" {
  type    = string
  default = "Standard"
}

variable "queue_name" {
  type    = string
  default = "inbound-messages"
}

variable "queue_max_delivery_count" {
  description = "Failed deliveries before a message is dead-lettered."
  type        = number
  default     = 5
}

# --- Scaling ---------------------------------------------------------------

variable "api_min_replicas" {
  description = "1+ in prod to avoid cold starts on inbound webhooks."
  type        = number
  default     = 0
}

variable "api_max_replicas" {
  type    = number
  default = 5
}

variable "worker_max_replicas" {
  type    = number
  default = 10
}

variable "worker_messages_per_replica" {
  description = "KEDA target: one worker replica per N messages waiting in the queue."
  type        = number
  default     = 5
}

# --- Key Vault / logging ---------------------------------------------------

variable "key_vault_purge_protection" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "log_daily_quota_gb" {
  type    = number
  default = -1
}

variable "tags" {
  type    = map(string)
  default = {}
}
