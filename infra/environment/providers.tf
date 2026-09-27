# Authentication comes from the environment, never from code:
#   CI     ARM_USE_OIDC=true + ARM_CLIENT_ID/ARM_TENANT_ID/ARM_SUBSCRIPTION_ID (GitHub OIDC)
#   laptop `az login` + ARM_SUBSCRIPTION_ID

provider "azurerm" {
  # The deployer identity is scoped to one resource group and cannot register
  # resource providers at subscription level; bootstrap does that once.
  resource_provider_registrations = "none"

  features {
    key_vault {
      # Purging needs subscription-level rights and would defeat soft delete.
      purge_soft_delete_on_destroy          = false
      purge_soft_deleted_secrets_on_destroy = false
      recover_soft_deleted_key_vaults       = true
      recover_soft_deleted_secrets          = true
    }
  }
}

provider "azapi" {}
