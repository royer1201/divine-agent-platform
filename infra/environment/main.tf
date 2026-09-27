# One stack, instantiated once per environment (dev, prod) with its own tfvars,
# state file, resource group and deployer identity.
#
#   webhook --> [API app] --send--> [Service Bus queue] --receive--> [Worker app]
#                                           |  \__ KEDA scaler (queue length)
#                                           +-- DLQ --> metric alert --> email
#   Worker <-- AI_API_KEY (Key Vault reference, managed identity)
#   Worker --> Cosmos DB (upsert by message_id, managed identity)
#   All logs --> Log Analytics

data "azurerm_resource_group" "this" {
  name = "rg-${var.project}-${var.environment}"
}

data "azurerm_container_registry" "shared" {
  name                = var.acr_name
  resource_group_name = "rg-${var.project}-shared"
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  name     = "${var.project}-${var.environment}"
  suffix   = random_string.suffix.result
  location = data.azurerm_resource_group.this.location

  ai_api_key_secret_name = "ai-api-key"

  tags = merge(var.tags, {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  })
}

module "log_analytics" {
  source = "../modules/log_analytics"

  name                = "log-${local.name}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = local.location
  retention_in_days   = var.log_retention_days
  daily_quota_gb      = var.log_daily_quota_gb
  tags                = local.tags
}

module "container_apps_environment" {
  source = "../modules/container_apps_environment"

  name                       = "cae-${local.name}"
  resource_group_name        = data.azurerm_resource_group.this.name
  location                   = local.location
  log_analytics_workspace_id = module.log_analytics.id
  tags                       = local.tags
}

module "service_bus" {
  source = "../modules/service_bus"

  name                = "sb-${local.name}-${local.suffix}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = local.location
  sku                 = var.servicebus_sku
  queue_names         = [var.queue_name]
  max_delivery_count  = var.queue_max_delivery_count
  tags                = local.tags
}

module "key_vault" {
  source = "../modules/key_vault"

  name                       = "kv-${local.name}-${local.suffix}"
  resource_group_name        = data.azurerm_resource_group.this.name
  location                   = local.location
  secret_names               = [local.ai_api_key_secret_name]
  purge_protection_enabled   = var.key_vault_purge_protection
  log_analytics_workspace_id = module.log_analytics.id
  tags                       = local.tags
}

# Bonus: every processed message is persisted. Serverless, Entra ID only.
module "cosmos_db" {
  source = "../modules/cosmos_db"

  name                = "cosmos-${local.name}-${local.suffix}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = local.location
  tags                = local.tags

  data_contributor_principal_ids = {
    worker = module.worker_identity.principal_id
  }
}

module "dlq_alert" {
  source = "../modules/dlq_alert"

  name_prefix             = local.name
  resource_group_name     = data.azurerm_resource_group.this.name
  servicebus_namespace_id = module.service_bus.namespace_id
  queue_names             = [var.queue_name]
  alert_email             = var.alert_email
  tags                    = local.tags
}
