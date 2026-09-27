output "id" {
  value = azurerm_key_vault.this.id
}

output "name" {
  value = azurerm_key_vault.this.name
}

output "uri" {
  value = azurerm_key_vault.this.vault_uri
}

output "secret_versionless_uris" {
  description = "Data-plane URIs without a version, for Container Apps Key Vault references."
  value       = { for name, s in azurerm_key_vault_secret.this : name => s.versionless_id }
}

output "secret_resource_ids" {
  description = "ARM resource IDs of the secrets, used as RBAC scopes (per-secret least privilege)."
  value       = { for name, s in azurerm_key_vault_secret.this : name => s.resource_versionless_id }
}
