# terraform/compute — Tier 2

Provisions the AKS cluster and NAT Gateway. Depends on foundation (managed
identity IDs) and platform/connectivity (subnet IDs).

## Resources

| Resource                | Name               | Purpose                                 |
| ----------------------- | ------------------ | --------------------------------------- |
| Public IP               | `pip-nat-taskflow` | Static egress IP for NAT Gateway        |
| NAT Gateway             | `nat-taskflow`     | AKS node internet egress — bypasses NVA |
| NAT Gateway association | —                  | Attaches NAT Gateway to snet-aks        |
| AKS Cluster             | `aks-taskflow`     | Container platform                      |
| Node pool (system)      | `system`           | kube-system workloads only              |
| Node pool (workload)    | `workload`         | Application workloads, autoscaling      |

## Dependencies

| Source                  | Outputs consumed                         |
| ----------------------- | ---------------------------------------- |
| `platform/connectivity` | `rg_taskflow_name`, `snet_aks_id`        |
| `platform/management`   | `log_analytics_workspace_id`             |
| `terraform/foundation`  | `mi_*_id` (managed identity IDs for AKS) |

## Critical outputs

| Output                       | Why it matters                                                                                          |
| ---------------------------- | ------------------------------------------------------------------------------------------------------- |
| `oidc_issuer_url`            | Bindings tier uses this to create federated credentials. Without it, workload identity cannot function. |
| `kubelet_identity_object_id` | Bindings tier assigns AcrPull to this identity. Without it, AKS nodes cannot pull images from ACR.      |

## Design notes

**NAT Gateway in rg-taskflow, association on snet-aks in rg-workloads**
The taskflow SP holds Contributor on rg-taskflow (creates NAT Gateway) and
Network Contributor on rg-workloads (permits subnet association). No platform
change is required for this.

**outbound_type = userAssignedNATGateway**
This is set at cluster creation and cannot be changed. If omitted, AKS
defaults to a managed load balancer for egress, which conflicts with the
NAT Gateway design.

**API server access**
The API server is public with authorized_ip_ranges for local kubectl access.
CI/CD pipelines use `az aks command invoke` — no runner IP management needed.
