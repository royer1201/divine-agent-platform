variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "retention_in_days" {
  description = "Log retention. 30 is the free-retention floor for PerGB2018."
  type        = number
  default     = 30
}

variable "daily_quota_gb" {
  description = "Daily ingestion cap in GB; -1 means unlimited. A cap protects dev from a runaway log loop."
  type        = number
  default     = -1
}

variable "tags" {
  type    = map(string)
  default = {}
}
