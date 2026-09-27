locals {
  common_env = [
    { name = "SERVICEBUS_FQDN", value = module.service_bus.fqdn },
    { name = "SERVICEBUS_QUEUE", value = var.queue_name },
    { name = "APP_ENV", value = var.environment },
  ]
}

module "api" {
  source = "../modules/container_app"

  name              = "ca-${var.project}-api-${var.environment}"
  container_name    = "api"
  resource_group_id = data.azurerm_resource_group.this.id
  location          = local.location
  environment_id    = module.container_apps_environment.id
  identity_id       = module.api_identity.id
  registry_server   = data.azurerm_container_registry.shared.login_server
  image             = "${data.azurerm_container_registry.shared.login_server}/api:${var.image_tag}"
  health_probe_path = "/health"
  min_replicas      = var.api_min_replicas
  max_replicas      = var.api_max_replicas
  tags              = local.tags

  ingress = {
    external    = true
    target_port = 8080
  }

  env = concat(local.common_env, [
    { name = "AZURE_CLIENT_ID", value = module.api_identity.client_id },
  ])

  scale_rules = [
    {
      name = "http-concurrency"

      http = {
        metadata = { concurrentRequests = "50" }
      }
    },
  ]

  depends_on = [time_sleep.rbac_propagation]
}

module "worker" {
  source = "../modules/container_app"

  name                    = "ca-${var.project}-worker-${var.environment}"
  container_name          = "worker"
  resource_group_id       = data.azurerm_resource_group.this.id
  location                = local.location
  environment_id          = module.container_apps_environment.id
  identity_id             = module.worker_identity.id
  additional_identity_ids = [module.scaler_identity.id]
  registry_server         = data.azurerm_container_registry.shared.login_server
  image                   = "${data.azurerm_container_registry.shared.login_server}/worker:${var.image_tag}"
  min_replicas            = 0
  max_replicas            = var.worker_max_replicas
  tags                    = local.tags

  key_vault_secrets = {
    (local.ai_api_key_secret_name) = module.key_vault.secret_versionless_uris[local.ai_api_key_secret_name]
  }

  env = concat(local.common_env, [
    { name = "AZURE_CLIENT_ID", value = module.worker_identity.client_id },
    { name = "AI_API_KEY", secretRef = local.ai_api_key_secret_name },
  ])

  # KEDA azure-servicebus scaler, authenticated with the scaler's managed identity.
  # desired replicas = ceil(active messages / messageCount); min_replicas = 0 means
  # the worker scales to zero when the queue is empty.
  scale_rules = [
    {
      name = "servicebus-queue-length"

      custom = {
        type     = "azure-servicebus"
        identity = module.scaler_identity.id

        metadata = {
          namespace    = module.service_bus.namespace_name
          queueName    = var.queue_name
          messageCount = tostring(var.worker_messages_per_replica)
        }
      }
    },
  ]

  depends_on = [time_sleep.rbac_propagation]
}
