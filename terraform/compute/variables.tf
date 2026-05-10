variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}

variable "environment" {
  description = "Environment tag applied to all resources"
  type        = string
  default     = "dev"
}

variable "aks_sku_tier" {
  description = "AKS control plane SKU. Free for dev, Standard for production (SLA-backed)."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.aks_sku_tier)
    error_message = "aks_sku_tier must be Free, Standard, or Premium."
  }
}

variable "system_node_vm_size" {
  description = "VM size for the system node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "workload_node_vm_size" {
  description = "VM size for the workload node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "workload_node_min_count" {
  description = "Minimum node count for the workload node pool (autoscaler)"
  type        = number
  default     = 1
}

variable "workload_node_max_count" {
  description = "Maximum node count for the workload node pool (autoscaler)"
  type        = number
  default     = 3
}

variable "authorized_ip_ranges" {
  description = "IP ranges permitted to reach the AKS API server. For local kubectl access only — pipeline uses az aks command invoke."
  type        = list(string)
  default     = []
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster and node pools"
  type        = string
  default     = null # null = use latest stable
}
