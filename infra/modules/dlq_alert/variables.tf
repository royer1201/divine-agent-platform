variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "servicebus_namespace_id" {
  type = string
}

variable "queue_names" {
  type = list(string)
}

variable "alert_email" {
  description = "Where the alert is sent. Not a secret, but kept out of git and passed in by the pipeline."
  type        = string
}

variable "threshold" {
  description = "Alert when the DLQ holds more than this many messages."
  type        = number
  default     = 0
}

variable "severity" {
  description = "0 = critical ... 4 = verbose."
  type        = number
  default     = 2
}

variable "tags" {
  type    = map(string)
  default = {}
}
