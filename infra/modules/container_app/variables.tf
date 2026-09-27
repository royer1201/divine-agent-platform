variable "name" {
  type = string
}

variable "container_name" {
  type = string
}

variable "resource_group_id" {
  type = string
}

variable "location" {
  type = string
}

variable "environment_id" {
  description = "Container Apps managed environment ID."
  type        = string
}

variable "identity_id" {
  description = "User-assigned identity used for ACR pulls, Key Vault references and (via AZURE_CLIENT_ID) by the code."
  type        = string
}

variable "additional_identity_ids" {
  description = "Extra identities attached to the app, e.g. a dedicated identity for a KEDA scale rule."
  type        = list(string)
  default     = []
}

variable "registry_server" {
  type = string
}

variable "image" {
  type = string
}

variable "cpu" {
  type    = number
  default = 0.25
}

variable "memory" {
  description = "Must match the CPU tier, e.g. 0.25 CPU -> 0.5Gi."
  type        = string
  default     = "0.5Gi"
}

variable "env" {
  description = "Container env vars in ARM shape: [{ name, value }] or [{ name, secretRef }]."
  type        = any
  default     = []
}

variable "key_vault_secrets" {
  description = "Container App secret name -> versionless Key Vault secret URI."
  type        = map(string)
  default     = {}
}

variable "ingress" {
  description = "null = no ingress (background worker)."
  type = object({
    external    = bool
    target_port = number
  })
  default = null
}

variable "health_probe_path" {
  description = "HTTP path for liveness/readiness probes on the ingress port. null = platform defaults."
  type        = string
  default     = null
}

variable "min_replicas" {
  type    = number
  default = 0
}

variable "max_replicas" {
  type    = number
  default = 10
}

variable "scale_rules" {
  description = "KEDA scale rules in ARM shape (properties.template.scale.rules)."
  type        = any
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
