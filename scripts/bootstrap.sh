#!/usr/bin/env bash
# One-time setup, run by a subscription Owner from a laptop:
#   1. registers the resource providers the workload needs
#   2. applies infra/bootstrap (state storage, shared ACR, env resource groups,
#      GitHub OIDC identities + least-privilege RBAC)
#   3. prints the `gh` commands that configure the repository variables
#
# Usage: GITHUB_REPOSITORY=owner/repo ALERT_EMAIL=you@example.com ./scripts/bootstrap.sh
set -euo pipefail

: "${GITHUB_REPOSITORY:?set GITHUB_REPOSITORY=owner/repo}"
: "${ALERT_EMAIL:?set ALERT_EMAIL=you@example.com}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

az account show --query "{subscription:name, id:id, user:user.name}" -o table
read -r -p "Bootstrap into this subscription? [y/N] " answer
[[ "${answer}" == "y" ]] || exit 1

export ARM_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

for ns in Microsoft.App Microsoft.ContainerRegistry Microsoft.ServiceBus Microsoft.KeyVault \
          Microsoft.OperationalInsights Microsoft.Insights Microsoft.ManagedIdentity Microsoft.Storage \
          Microsoft.DocumentDB Microsoft.Consumption; do
  echo "Registering ${ns}..."
  az provider register --namespace "${ns}" --wait
done

cd "${ROOT}/infra/bootstrap"
terraform init -input=false
terraform apply -input=false \
  -var "github_repository=${GITHUB_REPOSITORY}" \
  -var "alert_email=${ALERT_EMAIL}"

echo
echo "==> Run these inside your clone to configure GitHub (requires gh auth login):"
terraform output -raw github_setup_commands
echo
echo "(The last command makes you a required reviewer for the prod environment.)"
