variable "name" {
  description = "Globally unique vault name, 3-24 characters."
  type        = string

  validation {
    condition     = length(var.name) >= 3 && length(var.name) <= 24
    error_message = "Key Vault names must be 3-24 characters."
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "secret_names" {
  description = "Secrets to create with a placeholder value."
  type        = list(string)
  default     = []
}

variable "soft_delete_retention_days" {
  type    = number
  default = 7
}

variable "purge_protection_enabled" {
  description = "Should be true in prod. Leave false in dev so teardown is clean."
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
