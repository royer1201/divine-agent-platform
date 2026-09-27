# One registry shared by all environments: images are built once and the same
# immutable tag (the git SHA) is promoted from dev to prod.

resource "azurerm_container_registry" "shared" {
  name                = "acr${var.project}${local.suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  sku                 = "Basic"

  # No admin user: pulls use the apps' managed identities, pushes use the CI identity.
  admin_enabled = false

  tags = local.tags
}
