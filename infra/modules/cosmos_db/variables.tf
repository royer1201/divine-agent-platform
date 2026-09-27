variable "name" {
  description = "Globally unique account name, 3-44 lowercase characters."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "database_name" {
  type    = string
  default = "agent-platform"
}

variable "container_name" {
  type    = string
  default = "messages"
}

variable "default_ttl_seconds" {
  description = "Per-document TTL; -1 keeps documents forever. Default 30 days."
  type        = number
  default     = 2592000
}

variable "data_contributor_principal_ids" {
  description = "Static label -> principal ID granted read/write on the container."
  type        = map(string)
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
