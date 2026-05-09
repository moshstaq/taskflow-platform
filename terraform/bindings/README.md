# terraform/bindings — Tier 3

The wiring tier. No new resources are created here — this tier connects
resources that already exist by creating role assignments, federated
credentials, and the Key Vault private endpoint.

Must be applied after both foundation and compute.

## Resources

| Resource                               | Purpose                                                                |
| -------------------------------------- | ---------------------------------------------------------------------- |
| `AcrPull` role assignment              | AKS kubelet identity → ACR. Nodes pull images without credentials.     |
| Federated credential (×3)              | Binds each managed identity to its Kubernetes ServiceAccount via OIDC. |
| `Key Vault Secrets User` (×3)          | Each service identity → Key Vault. Secrets read only.                  |
| `Azure Service Bus Data Sender` (×2)   | api-service + processor-service → Service Bus topic.                   |
| `Azure Service Bus Data Receiver` (×1) | notification-service ← Service Bus subscription.                       |
| Key Vault private endpoint             | Brings Key Vault into snet-compute. Requires DNS zone to resolve.      |

## Dependencies

| Source                  | Outputs consumed                                                         |
| ----------------------- | ------------------------------------------------------------------------ |
| `platform/connectivity` | `rg_taskflow_name`, `snet_compute_id`                                    |
| `terraform/foundation`  | All managed identity IDs + principal IDs, ACR ID, KV ID, SB namespace ID |
| `terraform/compute`     | `oidc_issuer_url`, `kubelet_identity_object_id`                          |

## Why this tier exists

The circular dependency between AKS (needs identity to exist) and federated
credentials (need AKS OIDC URL to exist) cannot be resolved in a single apply.

Splitting into three tiers breaks the circle:

- foundation: create identities (no OIDC URL needed)
- compute: create AKS referencing identities (OIDC URL now exists as output)
- bindings: create federated credentials using OIDC URL

## Private DNS note

The Key Vault private endpoint is provisioned here but will not resolve until
`platform/connectivity` provisions the `privatelink.vaultcore.azure.net` zone
and VNet link. When that happens, uncomment the `azurerm_private_dns_a_record`
block in main.tf.
