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

variable "kubernetes_namespace" {
  description = "Kubernetes namespace where taskflow services are deployed"
  type        = string
  default     = "taskflow"
}
