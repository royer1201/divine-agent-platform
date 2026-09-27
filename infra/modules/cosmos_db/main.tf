# Serverless Cosmos DB (NoSQL API) for message persistence.
# Serverless = pay per request unit, nothing when idle; right for a bursty,
# low-volume workload and for a demo. Entra ID only: account keys are disabled.

resource "azurerm_cosmosdb_account" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  minimal_tls_version = "Tls12"

  # No primary/secondary keys or connection strings: data-plane access is
  # Cosmos DB RBAC with managed identities only.
  local_authentication_enabled = false

  capabilities {
    name = "EnableServerless"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  tags = var.tags
}

resource "azurerm_cosmosdb_sql_database" "this" {
  name                = var.database_name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
}

# id = message_id, so a redelivered Service Bus message is an idempotent upsert,
# not a duplicate document.
resource "azurerm_cosmosdb_sql_container" "this" {
  name                = var.container_name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = azurerm_cosmosdb_sql_database.this.name
  partition_key_paths = ["/id"]
  default_ttl         = var.default_ttl_seconds
}

# Cosmos DB data-plane RBAC (separate from Azure RBAC): built-in
# "Cosmos DB Built-in Data Contributor", scoped to this one container.
resource "azurerm_cosmosdb_sql_role_assignment" "data_contributor" {
  for_each = var.data_contributor_principal_ids

  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  role_definition_id  = "${azurerm_cosmosdb_account.this.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = each.value
  scope               = "${azurerm_cosmosdb_account.this.id}/dbs/${azurerm_cosmosdb_sql_database.this.name}/colls/${azurerm_cosmosdb_sql_container.this.name}"
}
