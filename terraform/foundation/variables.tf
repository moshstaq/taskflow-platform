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

variable "acr_sku" {
  description = "ACR SKU tier. Basic is sufficient for a single-cluster workload."
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "acr_sku must be Basic, Standard, or Premium."
  }
}

variable "service_bus_sku" {
  description = "Service Bus namespace SKU. Standard required for topics and subscriptions."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.service_bus_sku)
    error_message = "service_bus_sku must be Basic, Standard, or Premium."
  }
}
