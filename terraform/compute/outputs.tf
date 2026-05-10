# ── AKS ───────────────────────────────────────────────────────────────────────

output "aks_id" {
  description = "Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster. Consumed by the bindings tier to create federated credentials."
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet identity. Used as the principal for the AcrPull role assignment in the bindings tier."
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "nat_gateway_public_ip" {
  description = "Public IP address of the NAT Gateway. All AKS pod egress originates from this address."
  value       = azurerm_public_ip.nat.ip_address
}
