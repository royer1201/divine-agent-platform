variable "name" {
  description = "Globally unique namespace name."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku" {
  description = "Standard is enough for queues + DLQ metrics. Premium is required for private endpoints."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "sku must be Basic, Standard or Premium."
  }
}

variable "queue_names" {
  type = list(string)
}

variable "max_delivery_count" {
  type    = number
  default = 5
}

variable "lock_duration" {
  description = "ISO 8601 peek-lock duration; must exceed the worst-case processing time of one message."
  type        = string
  default     = "PT1M"
}

variable "default_message_ttl" {
  type    = string
  default = "P1D"
}

variable "tags" {
  type    = map(string)
  default = {}
}
