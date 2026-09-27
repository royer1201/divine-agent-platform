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

# Everything Azure needs is a non-secret identifier, so it goes into repository
# *variables*. The one GitHub secret is the alert email: not a credential, but
# personal data that must not show up in the public run logs (secrets are masked).
# Both environments only accept deployments from main, so pushing a branch cannot
# obtain an environment-scoped OIDC token. Paste this into a shell inside the clone.
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
    flatten([
      for env in var.environments : [
        "echo '{\"deployment_branch_policy\":{\"protected_branches\":false,\"custom_branch_policies\":true}}' | gh api --method PUT \"repos/${var.github_repository}/environments/${env}\" --input - >/dev/null",
        "gh api --method POST \"repos/${var.github_repository}/environments/${env}/deployment-branch-policies\" -f name=main >/dev/null",
      ]
    ]),
    [
      "gh secret set ALERT_EMAIL --body '${var.alert_email}'",
      "echo '{\"reviewers\":[{\"type\":\"User\",\"id\":'\"$(gh api user -q .id)\"'}],\"deployment_branch_policy\":{\"protected_branches\":false,\"custom_branch_policies\":true}}' | gh api --method PUT \"repos/${var.github_repository}/environments/prod\" --input - >/dev/null",
    ],
  ))
}
