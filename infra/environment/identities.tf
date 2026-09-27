# Every permission the workload has is declared in this file.
#
#   identity   role                            scope
#   ---------  ------------------------------  -----------------------------------
#   api        AcrPull                         shared registry
#   api        Azure Service Bus Data Sender   the queue (not the namespace)
#   worker     AcrPull                         shared registry
#   worker     Azure Service Bus Data Receiver the queue
#   worker     Key Vault Secrets User          the single secret ai-api-key (not the vault)
#   scaler     Azure Service Bus Data Owner    the queue - KEDA reads queue runtime
#                                              properties, which needs the Manage claim.
#                                              Kept on a separate identity that the
#                                              application code never uses.

module "api_identity" {
  source = "../modules/managed_identity"

  name                = "id-${var.project}-api-${var.environment}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = local.location
  tags                = local.tags

  role_assignments = {
    acr-pull = {
      scope = data.azurerm_container_registry.shared.id
      role  = "AcrPull"
    }
    servicebus-send = {
      scope = module.service_bus.queue_ids[var.queue_name]
      role  = "Azure Service Bus Data Sender"
    }
  }
}

module "worker_identity" {
  source = "../modules/managed_identity"

  name                = "id-${var.project}-worker-${var.environment}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = local.location
  tags                = local.tags

  role_assignments = {
    acr-pull = {
      scope = data.azurerm_container_registry.shared.id
      role  = "AcrPull"
    }
    servicebus-receive = {
      scope = module.service_bus.queue_ids[var.queue_name]
      role  = "Azure Service Bus Data Receiver"
    }
    keyvault-ai-api-key = {
      scope = module.key_vault.secret_resource_ids[local.ai_api_key_secret_name]
      role  = "Key Vault Secrets User"
    }
  }
}

module "scaler_identity" {
  source = "../modules/managed_identity"

  name                = "id-${var.project}-scaler-${var.environment}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = local.location
  tags                = local.tags

  role_assignments = {
    servicebus-queue-metrics = {
      scope = module.service_bus.queue_ids[var.queue_name]
      role  = "Azure Service Bus Data Owner"
    }
  }
}

# Entra ID role assignments are eventually consistent. Without a pause the first
# revision can fail to pull from ACR or to resolve the Key Vault reference.
resource "time_sleep" "rbac_propagation" {
  create_duration = "60s"

  triggers = {
    api    = join(",", values(module.api_identity.role_assignment_ids))
    worker = join(",", values(module.worker_identity.role_assignment_ids))
    scaler = join(",", values(module.scaler_identity.role_assignment_ids))
  }
}
