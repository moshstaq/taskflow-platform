# taskflow-platform

A containerised task processing platform running on AKS. Built to production patterns: zero-credential workload identity, Helm-based deployment, vulnerability-scanned images, and centralised observability.

---

## Architecture

Three microservices communicate via HTTP and Azure Service Bus:

```
[client] → ingress → api-service → processor-service → Service Bus → notification-service
```

| Service                | Responsibility                                              |
| ---------------------- | ----------------------------------------------------------- |
| `api-service`          | Accepts task submissions via REST, returns status           |
| `processor-service`    | Processes tasks, publishes completion events to Service Bus |
| `notification-service` | Consumes events from Service Bus, fires notifications       |

All services authenticate to Azure (Key Vault, Service Bus) using **workload identity** — no credentials stored anywhere.

---

## Infrastructure

| Layer      | Module                 | Key Resources                                   |
| ---------- | ---------------------- | ----------------------------------------------- |
| Foundation | `terraform/foundation` | ACR, Service Bus namespace, topic, subscription |
| Compute    | `terraform/compute`    | AKS (Azure CNI Overlay, Cilium), NAT Gateway    |
| Security   | `terraform/security`   | Key Vault, Private Endpoint, Managed Identities |

Platform networking (`rg-workloads`) is owned by [azure-landing-zone](https://github.com/moshstaq/azure-landing-zone). This repository consumes it via remote state and never modifies it.

---

## Pipelines

**Infrastructure:** Plan on PR, sequential apply by tier on merge to main. Drift detected weekly.

**Services:** Independent per-service pipelines triggered by path filters. Each runs: build → Trivy vulnerability scan → push to ACR → `helm upgrade`.

---

## Secrets — GitHub Actions

| Secret                  | Source                                                       |
| ----------------------- | ------------------------------------------------------------ |
| `AZURE_CLIENT_ID`       | `platform/identity/github-oidc` output: `taskflow_client_id` |
| `AZURE_TENANT_ID`       | `platform/identity/github-oidc` output: `tenant_id`          |
| `AZURE_SUBSCRIPTION_ID` | `platform/identity/github-oidc` output: `subscription_id`    |
| `ACR_NAME`              | Set after `terraform/foundation` first apply                 |

---

## Cost Management

All workload resources live in `rg-taskflow` and can be destroyed cleanly:

```bash
# Stop cluster (pause billing, preserves config)
az aks stop --resource-group rg-taskflow --name aks-taskflow

# Start cluster
az aks start --resource-group rg-taskflow --name aks-taskflow
```

Platform networking in `rg-workloads` is never destroyed by this repository.
