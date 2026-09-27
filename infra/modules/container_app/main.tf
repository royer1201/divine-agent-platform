# Generic Container App, written against the ARM API with azapi.
#
# Why azapi instead of azurerm_container_app: KEDA scale rules that authenticate
# with a *managed identity* (`scale.rules[].custom.identity`) are an ARM feature the
# azurerm resource does not expose. Without it the Service Bus scaler would need a
# SAS connection string, and the namespace has local (SAS) auth disabled on purpose.

locals {
  probe_port = try(var.ingress.target_port, 8080)

  probes = var.health_probe_path == null ? [] : [
    {
      type                = "Liveness"
      httpGet             = { path = var.health_probe_path, port = local.probe_port }
      initialDelaySeconds = 5
      periodSeconds       = 10
      failureThreshold    = 3
    },
    {
      type                = "Readiness"
      httpGet             = { path = var.health_probe_path, port = local.probe_port }
      initialDelaySeconds = 2
      periodSeconds       = 5
      failureThreshold    = 3
    },
  ]

  ingress = var.ingress == null ? null : {
    external      = var.ingress.external
    targetPort    = var.ingress.target_port
    transport     = "auto"
    allowInsecure = false

    traffic = [
      {
        latestRevision = true
        weight         = 100
      },
    ]
  }

  # Key Vault references: Container Apps fetches the secret with the app's managed
  # identity and exposes it to the container as an env var (secretRef). Using the
  # versionless URI means a rotated value is picked up without a Terraform change.
  secrets = [
    for name, uri in var.key_vault_secrets : {
      name        = name
      keyVaultUrl = uri
      identity    = var.identity_id
    }
  ]
}

resource "azapi_resource" "this" {
  type      = "Microsoft.App/containerApps@2025-01-01"
  name      = var.name
  parent_id = var.resource_group_id
  location  = var.location
  tags      = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = concat([var.identity_id], var.additional_identity_ids)
  }

  body = {
    properties = {
      environmentId = var.environment_id

      configuration = {
        activeRevisionsMode = "Single"
        ingress             = local.ingress
        secrets             = local.secrets

        registries = [
          {
            server   = var.registry_server
            identity = var.identity_id
          },
        ]
      }

      template = {
        containers = [
          {
            name   = var.container_name
            image  = var.image
            env    = var.env
            probes = local.probes

            resources = {
              cpu    = var.cpu
              memory = var.memory
            }
          },
        ]

        scale = {
          minReplicas = var.min_replicas
          maxReplicas = var.max_replicas
          rules       = var.scale_rules
        }
      }
    }
  }

  response_export_values = [
    "properties.configuration.ingress.fqdn",
    "properties.latestRevisionName",
  ]
}
