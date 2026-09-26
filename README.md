# taskflow-platform

A containerised task processing platform running on AKS. Built to production
patterns: zero-credential workload identity, Helm-based deployment,
vulnerability-scanned images, and centralised observability.

The three services are **deliberately minimal**. They exist to exercise the
platform's wiring — identity federation, RBAC scope, private DNS resolution and
asynchronous messaging — rather than to implement business logic. See
[Verification](#verification) for what a successful run proves and
[Known gaps](#known-gaps) for what it does not.

---

## Architecture

Three microservices communicate via HTTP and Azure Service Bus:

```
[client] → ingress → api-service → processor-service → Service Bus → notification-service
```

| Service                | Responsibility                                              |
| ---------------------- | ----------------------------------------------------------- |
| `api-service`          | Accepts task submissions via REST, returns a task ID        |
| `processor-service`    | Processes tasks, publishes completion events to Service Bus |
| `notification-service` | Consumes events from Service Bus, fires notifications       |

**Two hops, two patterns, deliberately.** `api-service → processor-service` is
synchronous HTTP over the cluster Service and Kubernetes DNS: the caller needs
an answer, so failure surfaces immediately as a 502. `processor-service →
notification-service` is asynchronous messaging: notifications are slow and
failure-prone, and task processing must not fail when they do.

`processor-service` and `notification-service` authenticate to Azure (Key
Vault, Service Bus) using **workload identity** — no credentials stored
anywhere. `api-service` calls no Azure service; its only dependency is the
in-cluster Service, resolved by Kubernetes DNS.

### Identity flow

1. Each ServiceAccount is annotated with its managed identity's client ID; the
   pod template carries `azure.workload.identity/use: "true"`.
2. At pod creation the AKS webhook injects `AZURE_CLIENT_ID`,
   `AZURE_TENANT_ID`, `AZURE_AUTHORITY_HOST` and `AZURE_FEDERATED_TOKEN_FILE`,
   and mounts a projected ServiceAccount token.
3. That token is signed by the **cluster**, with the cluster's OIDC issuer as
   `iss` and `system:serviceaccount:taskflow:<service>` as `sub`.
4. `DefaultAzureCredential` reads it and presents it to Entra, which validates
   the signature against the issuer's published keys, matches issuer and
   subject to the **federated credential** on the managed identity, and returns
   an access token for that identity.
5. Azure RBAC on the target resource authorises the call.

### Messaging

`task-events` is a **topic** with a single `notification-service`
**subscription**. Each subscription receives its own copy of every message, so
a second consumer (audit, analytics) can be added without changing the
publisher. With one subscription today it behaves as a queue; the topic buys
the option, not present capability.

Receives use **peek-lock**: a message is locked for 30 seconds and removed only
on `complete_message`. A crash or overrun redelivers it, so delivery is
at-least-once and consumers must be idempotent — hence `message_id` carrying
the task ID.

---

## Infrastructure

| Layer      | Module                 | Key Resources                                                                |
| ---------- | ---------------------- | ---------------------------------------------------------------------------- |
| Foundation | `terraform/foundation` | ACR, Service Bus namespace/topic/subscription, Key Vault, managed identities |
| Compute    | `terraform/compute`    | AKS (Azure CNI Overlay, Cilium), NAT Gateway                                 |
| Bindings   | `terraform/bindings`   | Federated credentials, role assignments, Key Vault private endpoint          |

Applied in that order; each consumes the previous through remote state.

The split is about **lifecycle and blast radius**, not a dependency cycle: the
chain identity → cluster → federated credential is a straight line Terraform
could order within one configuration. Separating them means `compute` can be
destroyed between sessions to control cost without touching the registry or the
vault, while `bindings` is reapplied to pick up the new cluster's OIDC issuer
URL.

Platform networking (`rg-workloads`) is owned by
[azure-landing-zone](https://github.com/moshstaq/azure-landing-zone). This
repository consumes it via remote state and never modifies it.

### Key Vault access path

Key Vault has `public_network_access_enabled = false` and is reachable only
through its private endpoint in `snet-compute`. Without DNS, the vault's
hostname resolves to its public IP and pods get a **connection timeout, not a
403** — the endpoint works; name resolution is the missing link.

The `privatelink.vaultcore.azure.net` zone is platform-owned, shared
subscription-wide, and lives in `azure-landing-zone`. This repository joins it
with a `private_dns_zone_group` on the endpoint rather than writing A records
into it, so Azure maintains the record, it follows the endpoint's IP, and it is
removed with the endpoint. No cross-repo write permission is required.

### Egress

AKS uses `outboundType = userAssignedNATGateway`. Egress to Service Bus and
Entra leaves through the NAT gateway, not the hub NVA, which handles east-west
traffic only.

---

## Pipelines

**Infrastructure:** Plan on PR, sequential apply by tier on merge to main.
Drift detected weekly.

**Services:** Independent per-service pipelines triggered by path filters. Each
runs: build → Trivy vulnerability scan → push to ACR → `helm upgrade`.

- Images are tagged with the commit SHA, never `latest`, so a rollout always
  references a new image.
- Trivy fails the build on HIGH or CRITICAL **before** the push to ACR.
- Deployment uses `az aks command invoke`, so the runner needs no API server
  access and the cluster's authorised IP ranges stay closed.

### Values injected at deploy time

ACR name, Service Bus FQDN, Key Vault URI and each identity's client ID carry a
Terraform-generated random suffix that changes on every rebuild, so all four
are looked up at deploy time and passed with `--set`. Charts declare them with
Helm's `required`, so a missing value fails the render rather than producing a
pod that crashes at runtime.

---

## Secrets — GitHub Actions

Set on the `azure-production` environment.

| Secret                  | Source                                                       |
| ----------------------- | ------------------------------------------------------------ |
| `AZURE_CLIENT_ID`       | `platform/identity/github-oidc` output: `taskflow_client_id` |
| `AZURE_TENANT_ID`       | `platform/identity/github-oidc` output: `tenant_id`          |
| `AZURE_SUBSCRIPTION_ID` | `platform/identity/github-oidc` output: `subscription_id`    |

These are identifiers, not credentials — the app registration holds no client
secret, only federated credentials. They are nonetheless the only values in the
system not reproducible from Terraform: if they are missing, `azure/login`
fails with "Not all values are present" before ever contacting Azure.

`ACR_NAME` is no longer required. The deploy workflow looks the registry up at
run time, since its name changes on every rebuild.

---

## Verification

With no ingress controller installed, the flow is exercised from inside the
cluster:

```bash
AKS=$(az aks list -g rg-taskflow --query "[0].name" -o tsv)

az aks command invoke -g rg-taskflow -n $AKS \
  -c "kubectl run curl-test -n taskflow --image=curlimages/curl --restart=Never --rm -i -- \
      curl -s -X POST http://api-service/task -H 'Content-Type: application/json' -d '{\"type\":\"demo\"}'"
```

Returns `202` with a `task_id`. Trace it end to end:

```bash
az aks command invoke -g rg-taskflow -n $AKS \
  -c "kubectl logs -n taskflow deploy/notification-service | grep -i notifying"
```

Confirm the broker settled it:

```bash
SB=$(az servicebus namespace list -g rg-taskflow --query "[0].name" -o tsv)
az servicebus topic subscription show -g rg-taskflow --namespace-name $SB \
  --topic-name task-events --name notification-service \
  --query "countDetails" -o json
```

`activeMessageCount: 0` with no dead letters means received and completed.

### What a successful run proves

| Evidence                                                                  | Verifies                                                                        |
| ------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| api-service reaches processor by name                                     | Kubernetes DNS, Service routing                                                 |
| `DefaultAzureCredential acquired a token from WorkloadIdentityCredential` | Federated credential subject, token exchange                                    |
| Message published and consumed                                            | Service Bus Sender and Receiver role assignments, topic and subscription wiring |
| `activeMessageCount` returns to 0                                         | Peek-lock settlement                                                            |
| `processor-service` starts without error                                  | Private endpoint, private DNS resolution, Key Vault Secrets User role           |

### What it does not prove

Ingress routing, TLS termination, autoscaling under load, dead-letter handling,
or behaviour across node failure.

---

## Known gaps

Stated rather than hidden. Each is a deliberate scope decision or a logged
defect.

- **No ingress controller.** The charts create Ingress resources, but nothing
  serves them, so they have no address. Testing is in-cluster.
- **Idempotency is in-memory.** `notification-service` tracks processed message
  IDs in a set: lost on restart, not shared across replicas. Enough to
  demonstrate duplicate detection; a real implementation needs a shared store.
- **Route is `/task`, singular.** Inconsistent with REST convention; pending.
- **`api-service` holds an unused Service Bus Sender role.** Only
  `processor-service` publishes. Pending removal.
- **`notification-service` PDB uses `minAvailable: 1` with one replica**, which
  blocks voluntary eviction and stalls node drains. Pending change to
  `maxUnavailable: 1`.
- **Service Bus is Standard**, so it has no private endpoint — Premium is
  required. Traffic egresses via the NAT gateway to the public endpoint,
  secured by `local_auth_enabled = false`: no SAS keys exist, so every call
  needs an Entra token and an RBAC role.
- **Liveness probes test the process, not its dependencies.** Correct for the
  HTTP services, but it means a dead consumer loop in `notification-service`
  reports healthy. Exceptions are now logged; a readiness probe reflecting
  consumer state would be the proper fix.

---

## Operational notes

Lessons from real failures during build and test.

- **Role assignments propagate asynchronously.** A pod started immediately
  after `terraform apply` can receive a 403 for a permission already correct in
  the portal. A restart resolves it.
- **A failed `asyncio` task can die silently.** Its exception is stored on the
  task object and surfaces only when that object is garbage collected. Until
  the consumer loop was wrapped in `try/except`, it failed with no log output
  while the pod reported healthy.
- **`aiohttp` is an optional extra of the async Azure SDK.** `pip install`
  succeeds without it and the failure appears only at runtime, when the
  credential builds its transport. Sync clients use `requests`, which ships as
  a dependency.
- **Pod age and name reveal whether a fix deployed.** Unchanged names after a
  push mean the image never landed, however convincing the logs look.
- **Azure SDK logging is verbose at INFO.** AMQP state transitions and HTTP
  headers bury service logs; `logging.getLogger("azure").setLevel(WARNING)`
  restores signal.

---

## Cost Management

All workload resources live in `rg-taskflow` and can be destroyed cleanly.

**To pause between sessions** — preserves configuration, stops node billing:

```bash
az aks stop --resource-group rg-taskflow --name aks-taskflow
az aks start --resource-group rg-taskflow --name aks-taskflow
```

**To destroy**, in reverse order, since each layer references the one below:

```bash
cd terraform/bindings  && terraform destroy
cd ../compute          && terraform destroy
cd ../foundation       && terraform destroy
```

Helm releases go with the cluster; the Key Vault DNS record is removed with the
private endpoint by its zone group.

Key Vault has purge protection enabled, so it enters soft delete for 90 days
and cannot be purged. The random name suffix means this does not block a
rebuild; deleted vaults can be listed with `az keyvault list-deleted -o table`.

Cost is concentrated in the AKS node pools and the NAT gateway, both removed by
destroying `compute`. Platform networking in `rg-workloads` is never destroyed
by this repository.
