# ── Remote State: Platform Connectivity ──────────────────────────────────────
# Reads networking outputs provisioned by platform/connectivity.
# This module consumes: rg_taskflow_name
# Platform must be applied before this module can be initialised.

data "terraform_remote_state" "connectivity" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate7tcl"
    container_name       = "tfstate"
    key                  = "platform-connectivity.tfstate"
  }
}

# ── Remote State: Platform Management ────────────────────────────────────────
# Reads observability outputs provisioned by platform/management.
# This module consumes: log_analytics_workspace_id
# Used to wire diagnostic settings for ACR, Service Bus, Key Vault.

data "terraform_remote_state" "management" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate7tcl"
    container_name       = "tfstate"
    key                  = "platform-management.tfstate"
  }
}

# ── Locals ────────────────────────────────────────────────────────────────────

locals {
  rg_name = data.terraform_remote_state.connectivity.outputs.rg_taskflow_name
  law_id  = data.terraform_remote_state.management.outputs.log_analytics_workspace_id

  common_tags = {
    environment = var.environment
    workload    = "taskflow"
    managed_by  = "terraform"
  }
}

# ── ACR ───────────────────────────────────────────────────────────────────────
# Container registry for all taskflow service images.
#
# Design decisions:
# - admin_enabled: false — images are pulled via AcrPull role assignment on
#   the AKS kubelet identity. No username/password ever used.
# - public_network_access_enabled: true — Basic SKU does not support private
#   endpoints. Images are pushed from GitHub Actions runners (public) and
#   pulled by AKS nodes (also public egress via NAT Gateway).
#
# TODO: implement azurerm_container_registry.taskflow
#   name                          = "crtaskflow<random_suffix>"
#   resource_group_name           = local.rg_name
#   location                      = var.location
#   sku                           = var.acr_sku
#   admin_enabled                 = false
#   tags                          = local.common_tags


# ── Service Bus ───────────────────────────────────────────────────────────────
# Async messaging between processor-service and notification-service.
# Topic/subscription model: processor publishes, notification-service consumes.
#
# Design decisions:
# - local_auth_enabled: false — forces workload identity authentication.
#   No connection strings are used anywhere. Role assignments are in the
#   bindings tier after managed identities exist.
# - Standard SKU required — Basic SKU does not support topics.
#
# TODO: implement azurerm_servicebus_namespace.taskflow
#   name                  = "sb-taskflow-<random_suffix>"
#   resource_group_name   = local.rg_name
#   location              = var.location
#   sku                   = var.service_bus_sku
#   local_auth_enabled    = false
#   tags                  = local.common_tags

# TODO: implement azurerm_servicebus_topic.task_events
#   name         = "task-events"
#   namespace_id = azurerm_servicebus_namespace.taskflow.id

# TODO: implement azurerm_servicebus_subscription.notification_service
#   name                = "notification-service"
#   topic_id            = azurerm_servicebus_topic.task_events.id
#   max_delivery_count  = 10


# ── Key Vault ─────────────────────────────────────────────────────────────────
# Central secret store for all taskflow services.
#
# Design decisions:
# - enable_rbac_authorization: true — no legacy access policies.
#   Secrets access is granted via role assignments in the bindings tier.
# - public_network_access_enabled: false — accessed via private endpoint only.
#   Private endpoint is provisioned in the bindings tier into snet-compute.
# - purge_protection_enabled: true — prevents accidental permanent deletion.
# - soft_delete_retention_days: 7 — minimum retention, sufficient for a lab.
#
# TODO: implement azurerm_key_vault.taskflow
#   name                          = "kv-taskflow-<random_suffix>"
#   resource_group_name           = local.rg_name
#   location                      = var.location
#   tenant_id                     = data.azurerm_client_config.current.tenant_id
#   sku_name                      = "standard"
#   enable_rbac_authorization     = true
#   public_network_access_enabled = false
#   purge_protection_enabled      = true
#   soft_delete_retention_days    = 7
#   tags                          = local.common_tags


# ── Managed Identities ────────────────────────────────────────────────────────
# One User Assigned Managed Identity per service that requires Azure resource
# access (Key Vault, Service Bus).
#
# Why created here (Tier 1) and not in the bindings tier:
# - AKS must reference the identities at cluster creation time so the
#   workload identity webhook can project tokens for them.
# - Federated credentials (which need the AKS OIDC issuer URL) are added
#   in the bindings tier after AKS exists. The identity itself is decoupled
#   from the federation — it is just a principal until bindings wires it up.
#
# TODO: implement azurerm_user_assigned_identity.api_service
#   name                = "mi-taskflow-api-service"
#   resource_group_name = local.rg_name
#   location            = var.location
#   tags                = local.common_tags

# TODO: implement azurerm_user_assigned_identity.processor_service
#   name                = "mi-taskflow-processor-service"
#   resource_group_name = local.rg_name
#   location            = var.location
#   tags                = local.common_tags

# TODO: implement azurerm_user_assigned_identity.notification_service
#   name                = "mi-taskflow-notification-service"
#   resource_group_name = local.rg_name
#   location            = var.location
#   tags                = local.common_tags
