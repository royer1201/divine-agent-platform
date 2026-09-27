# Walkthrough — what was built, how it was verified, what I learned

A 10-minute tour for reviewers. Setup and teardown instructions live in the [README](../README.md).

## 1. The problem in one sentence

Accept customer messages from any channel, **never lose one**, process them at whatever rate
they arrive, cost ~nothing when idle, and hold **zero secrets** anywhere.

```text
Customer ──POST /webhook/message──▶ API (Container App, HTTP scaler)
                                        │  managed identity: Data Sender
                                        ▼
                              Service Bus queue ──(5 failed deliveries)──▶ DLQ ──▶ metric alert ──▶ email
                                        │  managed identity: Data Receiver
                                        ▼
                        Worker (Container App, KEDA 0..N on queue length)
                           ├── AI_API_KEY  ◀── Key Vault reference (managed identity, one secret)
                           └── upsert by message_id ──▶ Cosmos DB serverless (managed identity, keys disabled)

Everything ──▶ Log Analytics          GitHub Actions ──OIDC (no secrets)──▶ ACR + Terraform ──▶ Azure
```

## 2. Requirement → where it lives

| Requirement | Implementation |
|---|---|
| API + worker as containers | [`app/api`](../app/api), [`app/worker`](../app/worker) — one Dockerfile each, non-root |
| IaC for ACR, Container Apps, Service Bus, Key Vault, Log Analytics | Terraform: [`infra/bootstrap`](../infra/bootstrap) (shared, once) · [`infra/environment`](../infra/environment) (per env) · 8 [`modules`](../infra/modules) |
| Service Bus via Managed Identity | RBAC on the **queue**; namespace `local_auth_enabled = false` (SAS impossible) |
| Worker reads `AI_API_KEY` via MI | Container Apps Key Vault reference; RBAC on **that one secret** |
| No secrets in the repo | None exist to leak; gitleaks gates every PR |
| KEDA incl. scale to zero | `azure-servicebus` scaler, `minReplicas = 0`, scaler authenticates with its **own** identity |
| CI/CD: build, push, deploy, OIDC | [`deploy.yml`](../.github/workflows/deploy.yml) → [`terraform.yml`](../.github/workflows/terraform.yml); Trivy gate; build once, promote the same SHA dev → prod |
| DLQ alert | [`modules/dlq_alert`](../infra/modules/dlq_alert): `DeadletteredMessages` > 0, per queue |
| Bonus: database | [`modules/cosmos_db`](../infra/modules/cosmos_db): serverless, keys disabled, data-plane RBAC scoped to the container |
| Bonus: dev / prod | Separate RGs, state containers, deployer identities, GitHub environments (prod = required reviewer) |
| Bonus: private endpoints | Not deployed — needs Service Bus Premium (~$670/month). Designed in the production section of the README |

## 3. Security model — the part worth 30%

- **No credentials anywhere.** Workload → Azure: user-assigned managed identities. GitHub → Azure:
  OIDC federated credentials. Key-based auth is *disabled* on Service Bus and Cosmos DB, and the
  registry has no admin user — so there is nothing to put in a secret even by mistake.
- **Least privilege, narrowest scope.** Sender/receiver roles on the queue, not the namespace;
  Key Vault role on one secret, not the vault; Cosmos role on one container. The KEDA scaler needs
  the *Manage* claim, so it gets a separate identity the code never uses.
- **The pipeline cannot escalate.** Deployer identities hold *Role Based Access Control
  Administrator* with an **ABAC condition** that allows assigning only five data-plane roles —
  never Owner/Contributor, not even to themselves. The dev identity cannot touch prod or read its state.
- **Trust pinned to immutable IDs.** Federated credentials match
  `repo:royer1201@94853736/divine-agent-platform@1390584733:...`, so a renamed or re-created repo
  with the same name cannot inherit Azure access.
- **Owner ≠ data access.** Being subscription Owner does not let you read customer messages in
  Cosmos DB; that needs an explicit data-plane role. That is intentional.
- **Supply chain.** Trivy blocks fixable critical CVEs; Dependabot (grouped) keeps actions,
  packages, base images and providers current.

## 4. Verified end to end on a real subscription

Deployed by the pipeline (no portal clicks) to `rg-divine-dev`, then exercised from Cloud Shell:

| Check | Result |
|---|---|
| Pipeline: OIDC login → build → Trivy → push → `terraform apply` → smoke test | ✅ green |
| `GET /health` | `{"status":"ok"}` |
| 150 webhooks, 20 in parallel | **150 × HTTP 202** |
| Messages processed by the worker (Log Analytics) | **163**, all `persisted: true` |
| Cosmos DB document | `id = message_id`, `received_at`, original `payload` |
| `AI_API_KEY` from Key Vault | loaded; only a SHA-256 prefix is logged (`33ffcfd1`) |
| Poison message (`simulate_failure: true`) | 5 deliveries → **dead-lettered** (DLQ = 2) |
| DLQ alert | **Fired** (Sev 2) → email |
| Scale to zero | worker 0 → 1 → **0**, graceful SIGTERM shutdown logged |
| Terraform plan on PRs over OIDC (`pull_request` subject) | ✅ |

## 5. Three real problems the live run caught

1. **Supply chain:** `aquasecurity/trivy-action@0.28.0` no longer resolves — after the 2026
   tag-hijack incident ([GHSA-69fq-xp46-6x23](https://osv.dev/vulnerability/GHSA-69fq-xp46-6x23))
   the old tags were deleted. Moved to `v0.36.0`; production answer: pin actions to commit SHAs.
2. **Identity:** the first login failed with `AADSTS700213`. GitHub now issues the OIDC `sub` with
   immutable owner/repo IDs, so name-based federated credentials never match. Fixed in bootstrap —
   and it is strictly more secure.
3. **Concurrency:** the load test returned 500s. The async Service Bus sender was opened lazily and
   raced on a cold replica. Now opened once at startup and serialized. Static checks could not
   have found this; a real deployment did.

## 6. Cost

Idle, per environment: ≈ $10/month (Service Bus Standard base); Container Apps, Cosmos DB
serverless and Log Analytics stay inside free grants at this volume. The shared ACR is ≈ $5/month.
A $10/month subscription budget alerts at 50% actual and 100% forecast. This demo environment
is torn down after review (README → Teardown).

## 7. Known gaps and next steps

- Bootstrap state is local (backed up to the state account); move it to the remote backend.
- Commit the provider lock files (`.terraform.lock.hcl`).
- Mask the alert e-mail and webhook URL in public run logs (open PR), plus pin actions to SHAs.
- Private networking, Front Door + WAF, webhook signature validation, OpenTelemetry tracing and
  SLO alerts — see "What I would change in a real production environment" in the README.
