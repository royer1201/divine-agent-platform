terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.20.0, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Local state on purpose: this stack creates the remote-state storage account
  # that every other stack uses. See README "Bootstrap" for migrating it afterwards.
}

provider "azurerm" {
  # The state storage account has shared-key auth disabled. Manage it (and its
  # containers, via storage_account_id) through the ARM control plane only, so
  # the provider never needs account keys or data-plane roles.
  storage_use_azuread = true

  features {
    storage {
      data_plane_available = false
    }
  }
}
