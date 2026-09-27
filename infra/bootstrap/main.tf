# Bootstrap = the one-time "landing zone" for this workload. Run it once, locally,
# as a subscription Owner. It creates everything the CI pipeline needs to exist
# *before* the pipeline can run, and nothing more:
#
#   rg-<project>-shared   remote state storage, shared ACR, GitHub OIDC identities
#   rg-<project>-<env>    empty resource group per environment (the pipeline fills it)
#
# The per-environment deployer identities get rights on their own resource group
# only, so the dev pipeline can never touch prod.

data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

locals {
  suffix = random_string.suffix.result

  tags = merge(var.tags, {
    project    = var.project
    managed_by = "terraform"
    stack      = "bootstrap"
  })
}

resource "azurerm_resource_group" "shared" {
  name     = "rg-${var.project}-shared"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "env" {
  for_each = toset(var.environments)

  name     = "rg-${var.project}-${each.key}"
  location = var.location
  tags     = merge(local.tags, { environment = each.key })
}
