variable "project" {
  description = "Short project name used as a prefix in resource names."
  type        = string
  default     = "divine"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,9}$", var.project))
    error_message = "project must be 3-10 lowercase alphanumeric characters (it is embedded in ACR and storage account names)."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "environments" {
  description = "Environments to create a resource group, state container and deployer identity for."
  type        = list(string)
  default     = ["dev", "prod"]
}

variable "plan_environment" {
  description = "Environment whose deployer identity may also be used by pull_request workflows (terraform plan)."
  type        = string
  default     = "dev"
}

variable "github_repository" {
  description = "GitHub repository in owner/name form. Used as the subject of the OIDC federated credentials."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like owner/repo."
  }
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default     = {}
}
