# ── Remote State: Foundation ──────────────────────────────────────────────────

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
  key_vault_name                    = data.terraform_remote_state.foundation.outputs.key_vault_name
  private_dns_zone_kv_rg            = data.terraform_remote_state.connectivity.outputs.private_dns_zone_kv_rg


  common_tags = {
    environment = var.environment
    workload    = "taskflow"
    managed_by  = "terraform"
  }
}


# ── AcrPull — Kubelet Identity ────────────────────────────────────────────────

#
resource "azurerm_role_assignment" "acr_pull" {
  scope                = local.acr_id
  role_definition_name = "AcrPull"
  principal_id         = local.kubelet_identity
}


# ── Federated Identity Credentials ───────────────────────────────────────────

resource "azurerm_federated_identity_credential" "api_service" {
  name                = "fed-taskflow-api-service"
  resource_group_name = local.rg_name
  parent_id           = local.mi_api_service_id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = local.oidc_issuer_url
  subject             = "system:serviceaccount:taskflow:api-service"
}

resource "azurerm_federated_identity_credential" "processor_service" {
  name                = "fed-taskflow-processor-service"
  resource_group_name = local.rg_name
  parent_id           = local.mi_processor_service_id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = local.oidc_issuer_url
  subject             = "system:serviceaccount:taskflow:processor-service"
}

resource "azurerm_federated_identity_credential" "notification_service" {
  name                = "fed-taskflow-notification-service"
  resource_group_name = local.rg_name
  parent_id           = local.mi_notification_service_id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = local.oidc_issuer_url
  subject             = "system:serviceaccount:taskflow:notification-service"
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

#
resource "azurerm_private_dns_a_record" "kv" {
  name                = local.key_vault_name
  zone_name           = "privatelink.vaultcore.azure.net"
  resource_group_name = local.private_dns_zone_kv_rg
  ttl                 = 300
  records             = [azurerm_private_endpoint.kv.private_service_connection[0].private_ip_address]
}
# -----------------------------------------------------------------------------


