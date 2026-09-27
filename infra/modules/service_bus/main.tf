resource "azurerm_servicebus_namespace" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  minimum_tls_version = "1.2"

  # Entra ID (RBAC) only. SAS keys and connection strings stop working entirely,
  # so nobody can "just grab the connection string" from the portal.
  local_auth_enabled = false

  tags = var.tags
}

resource "azurerm_servicebus_queue" "this" {
  for_each = toset(var.queue_names)

  name         = each.key
  namespace_id = azurerm_servicebus_namespace.this.id

  # A message that fails max_delivery_count times, or expires, lands in the DLQ
  # (<queue>/$DeadLetterQueue) instead of being lost or retried forever.
  max_delivery_count                   = var.max_delivery_count
  lock_duration                        = var.lock_duration
  default_message_ttl                  = var.default_message_ttl
  dead_lettering_on_message_expiration = true
}
