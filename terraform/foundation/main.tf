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

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

# ── ACR ───────────────────────────────────────────────────────────────────────
# Container registry for all taskflow service images.

resource "azurerm_container_registry" "acr" {
  name                = "crtaskflow${random_string.suffix.result}"
  resource_group_name = local.rg_name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = false

  tags = local.common_tags
}


# ── Service Bus ───────────────────────────────────────────────────────────────
# Async messaging between processor-service and notification-service.
# Topic/subscription model: processor publishes, notification-service consumes.

resource "azurerm_servicebus_namespace" "sb" {
  name                = "sb-taskflow-${random_string.suffix.result}"
  resource_group_name = local.rg_name
  location            = var.location
  sku                 = "Standard"
  local_auth_enabled  = false

  tags = local.common_tags
}

resource "azurerm_servicebus_topic" "task_events" {
  name         = "task-events"
  namespace_id = azurerm_servicebus_namespace.sb.id

  enable_partitioning   = true
  default_message_ttl   = "PT1H"
  max_size_in_megabytes = 1024
}

# TODO: implement azurerm_servicebus_subscription.notification_service
resource "azurerm_servicebus_subscription" "notification" {
  name               = "notification-service"
  topic_id           = azurerm_servicebus_topic.task_events.id
  max_delivery_count = 5

  lock_duration                        = "PT30S"
  dead_lettering_on_message_expiration = true
  default_message_ttl                  = "PT1H"
}


# ── Key Vault ─────────────────────────────────────────────────────────────────
# Central secret store for all taskflow services.
#
#
resource "azurerm_key_vault" "kv" {
  name                = "kv-taskflow-${random_string.suffix.result}"
  resource_group_name = local.rg_name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization     = true
  purge_protection_enabled      = true
  soft_delete_retention_days    = 90
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = local.common_tags
}


# ── Managed Identities ────────────────────────────────────────────────────────
# One User Assigned Managed Identity per service that requires Azure resource
# access (Key Vault, Service Bus).
#
resource "azurerm_user_assigned_identity" "mi_api_service" {
  name                = "mi-taskflow-api-service"
  resource_group_name = local.rg_name
  location            = var.location

  tags = local.common_tags
}

resource "azurerm_user_assigned_identity" "mi_processor_service" {
  name                = "mi-taskflow-processor-service"
  resource_group_name = local.rg_name
  location            = var.location

  tags = local.common_tags
}

resource "azurerm_user_assigned_identity" "mi_notification_service" {
  name                = "mi-taskflow-notification-service"
  resource_group_name = local.rg_name
  location            = var.location

  tags = local.common_tags
}


#----- Diagnostic Settings ───────────────────────────────────────────────────────
# Wires diagnostics from ACR, Service Bus, and Key Vault to the Log Analytics
# workspace provisioned by platform/management. 
resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "diag-acr-taskflow"
  target_resource_id         = azurerm_container_registry.acr.id
  log_analytics_workspace_id = local.law_id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true

  }
}

resource "azurerm_monitor_diagnostic_setting" "sb" {
  name                       = "diag-sb-taskflow"
  target_resource_id         = azurerm_servicebus_namespace.sb.id
  log_analytics_workspace_id = local.law_id

  enabled_log {
    category = "OperationalLogs"
  }

  enabled_log {
    category = "RuntimeAuditLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true

  }
}

resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "diag-kv-taskflow"
  target_resource_id         = azurerm_key_vault.kv.id
  log_analytics_workspace_id = local.law_id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true

  }
}
