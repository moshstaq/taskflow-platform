# ── AKS ───────────────────────────────────────────────────────────────────────

# TODO: output "aks_id" {
#   description = "Resource ID of the AKS cluster"
#   value       = azurerm_kubernetes_cluster.taskflow.id
# }

# TODO: output "aks_name" {
#   description = "Name of the AKS cluster — used by az aks command invoke in CI/CD"
#   value       = azurerm_kubernetes_cluster.taskflow.name
# }

# TODO: output "oidc_issuer_url" {
#   description = "OIDC issuer URL for the cluster. Required by bindings tier to create
#                  federated credentials on managed identities."
#   value       = azurerm_kubernetes_cluster.taskflow.oidc_issuer_url
# }

# TODO: output "kubelet_identity_object_id" {
#   description = "Object ID of the kubelet managed identity.
#                  Bindings tier assigns AcrPull on ACR to this identity so nodes can pull images."
#   value       = azurerm_kubernetes_cluster.taskflow.kubelet_identity[0].object_id
# }


# ── NAT Gateway ───────────────────────────────────────────────────────────────

# TODO: output "nat_gateway_public_ip" {
#   description = "Public IP address of the NAT Gateway — stable egress IP for AKS nodes"
#   value       = azurerm_public_ip.nat.ip_address
# }
