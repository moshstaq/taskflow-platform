# terraform/foundation — Tier 1

Provisions shared application infrastructure that has no upstream dependency
within this repository. Must be applied before compute or bindings.

## Resources

| Resource                 | Name pattern                       | Purpose                                    |
| ------------------------ | ---------------------------------- | ------------------------------------------ |
| ACR                      | `crtaskflow<suffix>`               | Container image registry                   |
| Service Bus Namespace    | `sb-taskflow-<suffix>`             | Async messaging backbone                   |
| Service Bus Topic        | `task-events`                      | Event stream from processor                |
| Service Bus Subscription | `notification-service`             | Consumer for notification-service          |
| Key Vault                | `kv-taskflow-<suffix>`             | Secret store, RBAC-only access             |
| Managed Identity         | `mi-taskflow-api-service`          | Workload identity for api-service          |
| Managed Identity         | `mi-taskflow-processor-service`    | Workload identity for processor-service    |
| Managed Identity         | `mi-taskflow-notification-service` | Workload identity for notification-service |

## Dependencies

| Source                  | Outputs consumed             |
| ----------------------- | ---------------------------- |
| `platform/connectivity` | `rg_taskflow_name`           |
| `platform/management`   | `log_analytics_workspace_id` |

## Outputs consumed by downstream tiers

| Output                          | Consumed by                                    |
| ------------------------------- | ---------------------------------------------- |
| `acr_id`, `acr_name`            | bindings (AcrPull assignment)                  |
| `service_bus_namespace_id`      | bindings (Service Bus role assignments)        |
| `key_vault_id`, `key_vault_uri` | bindings (private endpoint + role assignments) |
| `mi_*_id`                       | compute (AKS identity reference)               |
| `mi_*_client_id`                | bindings (federated credential) + Helm values  |
| `mi_*_principal_id`             | bindings (role assignments)                    |

## Why managed identities live here and not in bindings

AKS references managed identity IDs at cluster creation. The identity must
exist before compute applies. Federated credentials (which bind the identity
to a Kubernetes ServiceAccount via the AKS OIDC issuer URL) are added in the
bindings tier after the cluster exists.
