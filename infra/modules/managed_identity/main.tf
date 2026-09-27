# A user-assigned identity plus exactly the role assignments it needs.
# User-assigned (not system-assigned) so the identity and its permissions exist
# *before* the container app is created: the first revision can already pull
# from ACR and resolve Key Vault references.
resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.this.principal_id
  principal_type       = "ServicePrincipal"
  description          = "${var.name}: ${each.key}"
}
