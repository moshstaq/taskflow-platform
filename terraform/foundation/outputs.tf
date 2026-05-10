# ── ACR ───────────────────────────────────────────────────────────────────────
# Consumed by: bindings (AcrPull role assignment)

# TODO: output "acr_id" {
#   description = "Resource ID of the container registry"
#   value       = azurerm_container_registry.taskflow.id
# }

# TODO: output "acr_name" {
#   description = "Name of the container registry"
#   value       = azurerm_container_registry.taskflow.name
# }

# TODO: output "acr_login_server" {
#   description = "Login server URL for the container registry"
#   value       = azurerm_container_registry.taskflow.login_server
# }


# ── Service Bus ───────────────────────────────────────────────────────────────
# Consumed by: bindings (Service Bus role assignments)

# TODO: output "service_bus_namespace_id" {
#   description = "Resource ID of the Service Bus namespace"
#   value       = azurerm_servicebus_namespace.taskflow.id
# }

# TODO: output "service_bus_namespace_name" {
#   description = "Name of the Service Bus namespace"
#   value       = azurerm_servicebus_namespace.taskflow.name
# }


# ── Key Vault ─────────────────────────────────────────────────────────────────
# Consumed by: bindings (private endpoint + role assignments)

# TODO: output "key_vault_id" {
#   description = "Resource ID of the Key Vault"
#   value       = azurerm_key_vault.taskflow.id
# }

# TODO: output "key_vault_uri" {
#   description = "URI of the Key Vault — used by CSI driver SecretProviderClass"
#   value       = azurerm_key_vault.taskflow.vault_uri
# }

# TODO: output "key_vault_name" {
#   description = "Name of the Key Vault"
#   value       = azurerm_key_vault.taskflow.name
# }


# ── Managed Identities ────────────────────────────────────────────────────────
# Consumed by: compute (passed to AKS), bindings (federated creds + role assignments)
# client_id  — used in Kubernetes ServiceAccount annotation
# id         — used in AKS identity block
# principal_id — used for role assignments

# TODO: output "mi_api_service_id" {
#   value = azurerm_user_assigned_identity.api_service.id
# }
# TODO: output "mi_api_service_client_id" {
#   value = azurerm_user_assigned_identity.api_service.client_id
# }
# TODO: output "mi_api_service_principal_id" {
#   value = azurerm_user_assigned_identity.api_service.principal_id
# }

# TODO: output "mi_processor_service_id" {
#   value = azurerm_user_assigned_identity.processor_service.id
# }
# TODO: output "mi_processor_service_client_id" {
#   value = azurerm_user_assigned_identity.processor_service.client_id
# }
# TODO: output "mi_processor_service_principal_id" {
#   value = azurerm_user_assigned_identity.processor_service.principal_id
# }

# TODO: output "mi_notification_service_id" {
#   value = azurerm_user_assigned_identity.notification_service.id
# }
# TODO: output "mi_notification_service_client_id" {
#   value = azurerm_user_assigned_identity.notification_service.client_id
# }
# TODO: output "mi_notification_service_principal_id" {
#   value = azurerm_user_assigned_identity.notification_service.principal_id
# }
