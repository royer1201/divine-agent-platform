terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.20.0, < 5.6.1"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.2.0, < 3.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # Partial configuration: storage account, container and key are passed with
  # -backend-config at init time (see README / deploy workflow). Entra ID auth only.
  backend "azurerm" {
    use_azuread_auth = true
  }
}
