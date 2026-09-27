output "api_url" {
  value = "https://${module.api.fqdn}"
}

output "resource_group_name" {
  value = data.azurerm_resource_group.this.name
}

output "api_app_name" {
  value = module.api.name
}

output "worker_app_name" {
  value = module.worker.name
}

output "servicebus_namespace" {
  value = module.service_bus.namespace_name
}

output "queue_name" {
  value = var.queue_name
}

output "key_vault_name" {
  value = module.key_vault.name
}

output "log_analytics_workspace_id" {
  description = "Workspace GUID for `az monitor log-analytics query -w`."
  value       = module.log_analytics.workspace_id
}

output "cosmos_endpoint" {
  value = module.cosmos_db.endpoint
}
