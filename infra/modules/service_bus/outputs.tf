output "namespace_id" {
  value = azurerm_servicebus_namespace.this.id
}

output "namespace_name" {
  value = azurerm_servicebus_namespace.this.name
}

output "fqdn" {
  description = "Fully qualified namespace used by the SDKs with a token credential."
  value       = "${azurerm_servicebus_namespace.this.name}.servicebus.windows.net"
}

output "queue_ids" {
  value = { for name, q in azurerm_servicebus_queue.this : name => q.id }
}
