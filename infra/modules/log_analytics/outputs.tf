output "id" {
  value = azurerm_log_analytics_workspace.this.id
}

output "name" {
  value = azurerm_log_analytics_workspace.this.name
}

output "workspace_id" {
  description = "The workspace (customer) GUID, used by `az monitor log-analytics query`."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}
