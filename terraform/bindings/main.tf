# ── Remote State: Foundation ──────────────────────────────────────────────────
# Reads managed identity principal IDs and client IDs, ACR ID,
# Service Bus namespace ID, Key Vault ID.

data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate7tcl"
    container_name       = "tfstate"
    key                  = "taskflow-foundation.tfstate"
  }
}

# ── Remote State: Compute ─────────────────────────────────────────────────────
# Reads oidc_issuer_url and kubelet_identity_object_id from the AKS cluster.
# This is why bindings cannot run until compute has applied — the OIDC URL
# does not exist until the cluster exists.

data "terraform_remote_state" "compute" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate7tcl"
    container_name       = "tfstate"
    key                  = "taskflow-compute.tfstate"
  }
}

# ── Remote State: Platform Connectivity ──────────────────────────────────────
# Reads snet_compute_id for the Key Vault private endpoint.

data "terraform_remote_state" "connectivity" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate7tcl"
    container_name       = "tfstate"
    key                  = "platform-connectivity.tfstate"
  }
}

# ── Locals ────────────────────────────────────────────────────────────────────

locals {
  rg_name                           = data.terraform_remote_state.connectivity.outputs.rg_taskflow_name
  snet_compute_id                   = data.terraform_remote_state.connectivity.outputs.snet_compute_id
  oidc_issuer_url                   = data.terraform_remote_state.compute.outputs.oidc_issuer_url
  kubelet_identity                  = data.terraform_remote_state.compute.outputs.kubelet_identity_object_id
  acr_id                            = data.terraform_remote_state.foundation.outputs.acr_id
  key_vault_id                      = data.terraform_remote_state.foundation.outputs.key_vault_id
  api_service_principal_id          = data.terraform_remote_state.foundation.outputs.mi_api_service_principal_id
  processor_service_principal_id    = data.terraform_remote_state.foundation.outputs.mi_processor_service_principal_id
  notification_service_principal_id = data.terraform_remote_state.foundation.outputs.mi_notification_service_principal_id
  mi_api_service_id                 = data.terraform_remote_state.foundation.outputs.mi_api_service_id
  mi_processor_service_id           = data.terraform_remote_state.foundation.outputs.mi_processor_service_id
  mi_notification_service_id        = data.terraform_remote_state.foundation.outputs.mi_notification_service_id
  service_bus_namespace_id          = data.terraform_remote_state.foundation.outputs.service_bus_namespace_id

  common_tags = {
    environment = var.environment
    workload    = "taskflow"
    managed_by  = "terraform"
  }
}


# ── AcrPull — Kubelet Identity ────────────────────────────────────────────────
# Allows AKS nodes to pull images from ACR without credentials.
# The kubelet identity is created by AKS at cluster provisioning time —
# this is why the assignment cannot be in the foundation tier.
#
resource "azurerm_role_assignment" "acr_pull" {
  scope                = local.acr_id
  role_definition_name = "AcrPull"
  principal_id         = local.kubelet_identity
}


# ── Federated Identity Credentials ───────────────────────────────────────────
# Links each managed identity to its Kubernetes ServiceAccount via OIDC.
#
# Subject format: system:serviceaccount:<namespace>:<service-account-name>
# The service account name must match the name in the Helm chart serviceaccount.yaml.
#
# How it works:
#   1. Pod runs with a projected ServiceAccount token (OIDC JWT).
#   2. Azure AD validates the token against the OIDC issuer URL.
#   3. Subject claim must match the federated credential subject exactly.
#   4. Azure AD returns an access token scoped to the managed identity.
#   5. Pod uses that token to authenticate to Key Vault / Service Bus.

resource "azurerm_federated_identity_credential" "api_service" {
  name     = "fed-taskflow-api-service"
  audience = ["api://AzureADTokenExchange"]
  issuer   = local.oidc_issuer_url
  subject  = "system:serviceaccount:taskflow:api-service"
}

resource "azurerm_federated_identity_credential" "processor_service" {
  name     = "fed-taskflow-processor-service"
  audience = ["api://AzureADTokenExchange"]
  issuer   = local.oidc_issuer_url
  subject  = "system:serviceaccount:taskflow:processor-service"
}

resource "azurerm_federated_identity_credential" "notification_service" {
  name     = "fed-taskflow-notification-service"
  audience = ["api://AzureADTokenExchange"]
  issuer   = local.oidc_issuer_url
  subject  = "system:serviceaccount:taskflow:notification-service"
}


# ── Key Vault Role Assignments ────────────────────────────────────────────────
# Grants each service identity read access to Key Vault secrets.
# Key Vault uses RBAC (enable_rbac_authorization = true) — no access policies.
#
resource "azurerm_role_assignment" "kv_secrets_api_service" {
  scope                = local.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.api_service_principal_id
}

resource "azurerm_role_assignment" "kv_secrets_processor_service" {
  scope                = local.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.processor_service_principal_id
}

# TODO: implement azurerm_role_assignment.kv_notification_service
resource "azurerm_role_assignment" "kv_secrets_notification_service" {
  scope                = local.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.notification_service_principal_id
}


# ── Service Bus Role Assignments ──────────────────────────────────────────────
# api-service and processor-service publish events (Sender).
# notification-service consumes events (Receiver).
#
# Scope is the namespace — not the topic or subscription.
# Namespace-scoped roles cover all topics/subscriptions within it.

resource "azurerm_role_assignment" "sb_sender_api_service" {
  scope                = local.service_bus_namespace_id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = local.api_service_principal_id
}

# TODO: implement azurerm_role_assignment.sb_sender_processor_service
resource "azurerm_role_assignment" "sb_sender_processor_service" {
  scope                = local.service_bus_namespace_id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = local.processor_service_principal_id
}

# TODO: implement azurerm_role_assignment.sb_receiver_notification_service
resource "azurerm_role_assignment" "sb_receiver_notification_service" {
  scope                = local.service_bus_namespace_id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = local.notification_service_principal_id
}


# ── Key Vault Private Endpoint ────────────────────────────────────────────────
# Places a private NIC for Key Vault into snet-compute (10.1.1.0/24).
# Traffic from AKS pods to Key Vault stays within the VNet.
#
# DNS note:
#   A private endpoint without a DNS zone resolves to the public IP — the
#   connection will be rejected because public access is disabled on the vault.
#   When platform/connectivity provisions the privatelink.vaultcore.azure.net
#   zone, add an azurerm_private_dns_a_record here pointing to the NIC IP
#   of this endpoint.
#   Until then, this endpoint is provisioned but not resolvable.
#
# TODO: implement azurerm_private_endpoint.key_vault
resource "azurerm_private_endpoint" "kv" {
  name                = "pe-kv-taskflow"
  resource_group_name = local.rg_name
  location            = var.location
  subnet_id           = local.snet_compute_id

  private_service_connection {
    name                           = "pe-kv-taskflow-conn"
    private_connection_resource_id = local.key_vault_id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# DNS A record — ON DEMAND ONLY
# Uncomment when the platform deploys the privatelink.vaultcore.azure.net zone.
#
# Without that zone, this private endpoint provisions successfully and receives
# a private IP in snet-compute, but Key Vault's hostname continues to resolve
# to its public IP. Because public_network_access_enabled = false on the vault,
# services will receive a connection timeout — not a 403. The PE is functional;
# the DNS is the missing link.
#
# resource "azurerm_private_dns_a_record" "kv" {
#   name                = local.key_vault_name
#   zone_name           = "privatelink.vaultcore.azure.net"
#   resource_group_name = "<platform-dns-rg>"
#   ttl                 = 300
#   records             = [azurerm_private_endpoint.kv.private_service_connection[0].private_ip_address]
# }
# -----------------------------------------------------------------------------

# ── Private DNS A Record (on-demand) ─────────────────────────────────────────
# Add this block when platform/connectivity provisions the DNS zone.
# Until then, leave commented.
#
# TODO: implement azurerm_private_dns_a_record.key_vault (when DNS zone exists)
#   name                = "kv-taskflow"
#   zone_name           = "privatelink.vaultcore.azure.net"
#   resource_group_name = <platform connectivity RG>
#   ttl                 = 300
#   records             = [azurerm_private_endpoint.key_vault.private_service_connection[0].private_ip_address]
