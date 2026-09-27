data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Azure RBAC data-plane authorization instead of legacy access policies, so
  # secret access is granted per secret and audited like every other role.
  rbac_authorization_enabled = true

  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  # Consumption Container Apps have no fixed egress IPs, so the vault stays on the
  # public endpoint (Entra ID + RBAC still required). Private endpoint = prod follow-up.
  public_network_access_enabled = true
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

# The secret *object* is managed here so the app can reference it on day one.
# The real value is never in git or in a pipeline variable: an operator sets it
# out of band (`az keyvault secret set ...`) and Terraform ignores the value from
# then on. The worker picks up new versions because it references the versionless URI.
resource "azurerm_key_vault_secret" "this" {
  for_each = toset(var.secret_names)

  name         = each.key
  value        = "placeholder-set-real-value-out-of-band"
  key_vault_id = azurerm_key_vault.this.id
  content_type = "text/plain"

  lifecycle {
    ignore_changes = [value]
  }
}

# Every secret read (including the worker's) lands in Log Analytics.
resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "audit-to-log-analytics"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }
}
