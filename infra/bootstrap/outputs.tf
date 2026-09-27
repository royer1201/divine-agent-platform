output "tfstate_resource_group" {
  value = azurerm_resource_group.shared.name
}

output "tfstate_storage_account" {
  value = azurerm_storage_account.tfstate.name
}

output "acr_name" {
  value = azurerm_container_registry.shared.name
}

output "acr_login_server" {
  value = azurerm_container_registry.shared.login_server
}

output "environment_resource_groups" {
  value = { for env, rg in azurerm_resource_group.env : env => rg.name }
}

output "github_build_client_id" {
  value = azurerm_user_assigned_identity.github_build.client_id
}

output "github_deploy_client_ids" {
  value = { for env, id in azurerm_user_assigned_identity.github_deploy : env => id.client_id }
}

# Everything GitHub needs is a non-secret identifier, so it goes into repository
# *variables*, not secrets. Paste this into a shell inside the repo clone.
output "github_setup_commands" {
  value = join("\n", concat(
    [
      "gh variable set AZURE_TENANT_ID --body '${data.azurerm_client_config.current.tenant_id}'",
      "gh variable set AZURE_SUBSCRIPTION_ID --body '${data.azurerm_subscription.current.subscription_id}'",
      "gh variable set AZURE_CLIENT_ID_BUILD --body '${azurerm_user_assigned_identity.github_build.client_id}'",
      "gh variable set TFSTATE_RESOURCE_GROUP --body '${azurerm_resource_group.shared.name}'",
      "gh variable set TFSTATE_STORAGE_ACCOUNT --body '${azurerm_storage_account.tfstate.name}'",
      "gh variable set ACR_NAME --body '${azurerm_container_registry.shared.name}'",
    ],
    [
      for env, id in azurerm_user_assigned_identity.github_deploy :
      "gh variable set AZURE_CLIENT_ID_${upper(env)} --body '${id.client_id}'"
    ],
    [
      for env in var.environments :
      "gh api --method PUT \"repos/${var.github_repository}/environments/${env}\" >/dev/null"
    ],
    [
      "gh variable set ALERT_EMAIL --body '${var.alert_email}'",
      "echo '{\"reviewers\":[{\"type\":\"User\",\"id\":'\"$(gh api user -q .id)\"'}]}' | gh api --method PUT \"repos/${var.github_repository}/environments/prod\" --input - >/dev/null",
    ],
  ))
}
