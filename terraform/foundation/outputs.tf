# ACR
output "acr_id" {
  description = "Resource ID of the Azure Container Registry."
  value       = azurerm_container_registry.acr.id
}

output "acr_name" {
  description = "Name of the Azure Container Registry."
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "Login server hostname of the Azure Container Registry."
  value       = azurerm_container_registry.acr.login_server
}

# Service Bus
output "service_bus_namespace_id" {
  description = "Resource ID of the Service Bus namespace."
  value       = azurerm_servicebus_namespace.sb.id
}

output "service_bus_namespace_name" {
  description = "Name of the Service Bus namespace."
  value       = azurerm_servicebus_namespace.sb.name
}

# Key Vault
output "key_vault_id" {
  description = "Resource ID of the Key Vault."
  value       = azurerm_key_vault.kv.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault. Used by services to construct secret references."
  value       = azurerm_key_vault.kv.vault_uri
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.kv.name
}

# Managed Identity — api-service
output "mi_api_service_id" {
  description = "Resource ID of the api-service managed identity."
  value       = azurerm_user_assigned_identity.mi_api_service.id
}

output "mi_api_service_client_id" {
  description = "Client ID of the api-service managed identity. Annotated onto the Kubernetes ServiceAccount."
  value       = azurerm_user_assigned_identity.mi_api_service.client_id
}

output "mi_api_service_principal_id" {
  description = "Principal ID of the api-service managed identity. Used as subject for RBAC role assignments."
  value       = azurerm_user_assigned_identity.mi_api_service.principal_id
}

# Managed Identity — processor-service
output "mi_processor_service_id" {
  description = "Resource ID of the processor-service managed identity."
  value       = azurerm_user_assigned_identity.mi_processor_service.id
}

output "mi_processor_service_client_id" {
  description = "Client ID of the processor-service managed identity. Annotated onto the Kubernetes ServiceAccount."
  value       = azurerm_user_assigned_identity.mi_processor_service.client_id
}

output "mi_processor_service_principal_id" {
  description = "Principal ID of the processor-service managed identity. Used as subject for RBAC role assignments."
  value       = azurerm_user_assigned_identity.mi_processor_service.principal_id
}

# Managed Identity — notification-service
output "mi_notification_service_id" {
  description = "Resource ID of the notification-service managed identity."
  value       = azurerm_user_assigned_identity.mi_notification_service.id
}

output "mi_notification_service_client_id" {
  description = "Client ID of the notification-service managed identity. Annotated onto the Kubernetes ServiceAccount."
  value       = azurerm_user_assigned_identity.mi_notification_service.client_id
}

output "mi_notification_service_principal_id" {
  description = "Principal ID of the notification-service managed identity. Used as subject for RBAC role assignments."
  value       = azurerm_user_assigned_identity.mi_notification_service.principal_id
}
