output "id" {
  value = azapi_resource.this.id
}

output "name" {
  value = azapi_resource.this.name
}

output "fqdn" {
  description = "Ingress FQDN, null for apps without ingress."
  value       = try(azapi_resource.this.output.properties.configuration.ingress.fqdn, null)
}

output "latest_revision_name" {
  value = try(azapi_resource.this.output.properties.latestRevisionName, null)
}
