# GitHub Actions -> Azure with OIDC workload identity federation.
# User-assigned managed identities are used instead of app registrations, so no
# Entra ID directory permissions are needed and there is no client secret to rotate.
#
#   id-<project>-github-build   AcrPush (+ Reader) on the shared registry only. Trusts: main branch.
#   id-<project>-github-<env>   Deploys one environment. Trusts: GitHub environment <env>
#                               (+ pull_request for the plan environment).

locals {
  github_issuer   = "https://token.actions.githubusercontent.com"
  github_audience = ["api://AzureADTokenExchange"]
  oidc_repo       = coalesce(var.github_oidc_repository, var.github_repository)

  # Built-in role definition IDs (identical in every tenant).
  role_ids = {
    acr_pull                = "7f951dda-4ed3-4680-a7ca-43fe172d538d"
    servicebus_data_sender  = "69a216fc-b8fb-44d8-bc22-1f3c2cd27a39"
    servicebus_data_receive = "4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0"
    servicebus_data_owner   = "090c5cfd-751d-490a-894a-3ce6f1109419"
    keyvault_secrets_user   = "4633458b-17de-408a-b874-0445c86b69e6"
  }

  # The deployer must create role assignments for the workload identities, but it
  # must NOT be able to grant itself (or anyone) Owner/Contributor. An ABAC condition
  # on "Role Based Access Control Administrator" limits which roles it can hand out.
  env_delegable_roles = [
    local.role_ids.servicebus_data_sender,
    local.role_ids.servicebus_data_receive,
    local.role_ids.servicebus_data_owner,
    local.role_ids.keyvault_secrets_user,
  ]
  acr_delegable_roles = [local.role_ids.acr_pull]

  rbac_condition_template = <<-EOT
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {%s}
     )
    )
    AND
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
     )
     OR
     (
      @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {%s}
     )
    )
  EOT

  env_rbac_condition = format(local.rbac_condition_template, join(", ", local.env_delegable_roles), join(", ", local.env_delegable_roles))
  acr_rbac_condition = format(local.rbac_condition_template, join(", ", local.acr_delegable_roles), join(", ", local.acr_delegable_roles))
}

# ---------------------------------------------------------------------------
# Build identity: can only push images.
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "github_build" {
  name                = "id-${var.project}-github-build"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "github_build_main" {
  name                = "github-main-branch"
  resource_group_name = azurerm_resource_group.shared.name
  parent_id           = azurerm_user_assigned_identity.github_build.id
  issuer              = local.github_issuer
  audience            = local.github_audience
  subject             = "repo:${local.oidc_repo}:ref:refs/heads/main"
}

# `az acr login` resolves the registry through ARM first, which AcrPush does not cover.
resource "azurerm_role_assignment" "github_build_acr_reader" {
  scope                = azurerm_container_registry.shared.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.github_build.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "github_build_acr_push" {
  scope                = azurerm_container_registry.shared.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.github_build.principal_id
  principal_type       = "ServicePrincipal"
}

# ---------------------------------------------------------------------------
# Per-environment deployer identities.
# ---------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "github_deploy" {
  for_each = toset(var.environments)

  name                = "id-${var.project}-github-${each.key}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  tags                = merge(local.tags, { environment = each.key })
}

resource "azurerm_federated_identity_credential" "github_deploy_environment" {
  for_each = toset(var.environments)

  name                = "github-environment-${each.key}"
  resource_group_name = azurerm_resource_group.shared.name
  parent_id           = azurerm_user_assigned_identity.github_deploy[each.key].id
  issuer              = local.github_issuer
  audience            = local.github_audience
  subject             = "repo:${local.oidc_repo}:environment:${each.key}"
}

# Pull requests run `terraform plan` against the plan environment. Azure rejects
# concurrent federated-credential writes on the same identity, hence depends_on.
resource "azurerm_federated_identity_credential" "github_deploy_pull_request" {
  name                = "github-pull-request"
  resource_group_name = azurerm_resource_group.shared.name
  parent_id           = azurerm_user_assigned_identity.github_deploy[var.plan_environment].id
  issuer              = local.github_issuer
  audience            = local.github_audience
  subject             = "repo:${local.oidc_repo}:pull_request"

  depends_on = [azurerm_federated_identity_credential.github_deploy_environment]
}

# Manage everything inside its own resource group...
resource "azurerm_role_assignment" "github_deploy_contributor" {
  for_each = toset(var.environments)

  scope                = azurerm_resource_group.env[each.key].id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_deploy[each.key].principal_id
  principal_type       = "ServicePrincipal"
}

# ...write the placeholder Key Vault secret (data plane is not covered by Contributor)...
resource "azurerm_role_assignment" "github_deploy_kv_secrets_officer" {
  for_each = toset(var.environments)

  scope                = azurerm_resource_group.env[each.key].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.github_deploy[each.key].principal_id
  principal_type       = "ServicePrincipal"
}

# ...grant only the data-plane roles the workload needs, inside its resource group...
resource "azurerm_role_assignment" "github_deploy_rbac_admin_env" {
  for_each = toset(var.environments)

  scope                = azurerm_resource_group.env[each.key].id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.github_deploy[each.key].principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = local.env_rbac_condition
}

# ...grant AcrPull (and nothing else) on the shared registry...
resource "azurerm_role_assignment" "github_deploy_rbac_admin_acr" {
  for_each = toset(var.environments)

  scope                = azurerm_container_registry.shared.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.github_deploy[each.key].principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = local.acr_rbac_condition
}

# ...and read/write its own Terraform state, not the other environment's.
resource "azurerm_role_assignment" "github_deploy_tfstate" {
  for_each = toset(var.environments)

  scope                = "${azurerm_storage_account.tfstate.id}/blobServices/default/containers/${azurerm_storage_container.tfstate[each.key].name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.github_deploy[each.key].principal_id
  principal_type       = "ServicePrincipal"
}

# ---------------------------------------------------------------------------
# The human running bootstrap: can run the environment stack locally and set the
# real AI_API_KEY value in Key Vault (the pipeline only creates a placeholder).
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "operator_tfstate" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "operator_kv_secrets_officer" {
  for_each = toset(var.environments)

  scope                = azurerm_resource_group.env[each.key].id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
