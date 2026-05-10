# ── Remote State: Platform Connectivity ──────────────────────────────────────
# Reads networking outputs provisioned by platform/connectivity.
# This module consumes: rg_taskflow_name, snet_aks_id

data "terraform_remote_state" "connectivity" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate7tcl"
    container_name       = "tfstate"
    key                  = "platform-connectivity.tfstate"
  }
}

# ── Remote State: Foundation ──────────────────────────────────────────────────
# Reads managed identity IDs provisioned by terraform/foundation.
# AKS kubelet identity and workload identities must exist before cluster creation.

data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate7tcl"
    container_name       = "tfstate"
    key                  = "taskflow-foundation.tfstate"
  }
}

# ── Remote State: Platform Management ────────────────────────────────────────
# Reads log_analytics_workspace_id for AKS diagnostic settings.

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
  rg_name     = data.terraform_remote_state.connectivity.outputs.rg_taskflow_name
  snet_aks_id = data.terraform_remote_state.connectivity.outputs.snet_aks_id
  law_id      = data.terraform_remote_state.management.outputs.log_analytics_workspace_id

  common_tags = {
    environment = var.environment
    workload    = "taskflow"
    managed_by  = "terraform"
  }
}

# ── NAT Gateway ───────────────────────────────────────────────────────────────
# Provides a stable, predictable egress IP for AKS node traffic.
#
# Design decisions:
# - NAT Gateway lives in rg-taskflow (workload-owned), not rg-workloads.
#   The taskflow SP has Contributor on rg-taskflow.
# - The subnet association attaches to snet-aks which is in rg-workloads.
#   The taskflow SP has Network Contributor on rg-workloads — this permits
#   the azurerm_subnet_nat_gateway_association resource.
# - AKS outbound_type must be set to userAssignedNATGateway at cluster
#   creation — this cannot be changed after the cluster exists.
# - Traffic path: AKS node → snet-aks → NAT Gateway → internet
#   The NVA only handles east-west (spoke-to-spoke). AKS egress bypasses it.

resource "azurerm_public_ip" "nat" {
  name                = "pip-nat-taskflow"
  resource_group_name = local.rg_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  tags = local.common_tags
}

resource "azurerm_nat_gateway" "nat" {
  name                    = "nat-taskflow"
  resource_group_name     = local.rg_name
  location                = var.location
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10

  tags = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "aks" {
  subnet_id      = local.snet_aks_id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}


# ── AKS ───────────────────────────────────────────────────────────────────────
# Design decisions:
#
# Azure CNI Overlay + Cilium:
#   network_plugin      = "azure"
#   network_plugin_mode = "overlay"
#   network_policy      = "cilium"
#   ebpf_data_plane     = "cilium"
#   CNI Overlay removes the pod IP exhaustion risk of standard CNI.
#   Cilium replaces the deprecated azure network policy engine.
#
# Workload identity:
#   oidc_issuer_enabled      = true
#   workload_identity_enabled = true
#   Required for pod-level managed identity via OIDC federation.
#   Federated credentials are wired in the bindings tier using the
#   oidc_issuer_url output from this module.
#
# Egress:
#   outbound_type = "userAssignedNATGateway"
#   Must match NAT Gateway above. Set at cluster creation — immutable.
#
# API server:
#   Public endpoint with authorized_ip_ranges.
#   CI/CD access via az aks command invoke — no runner IP management needed.
#   authorized_ip_ranges is for local kubectl access only.
#
# Node pools:
#   System pool: only_critical_addons_enabled = true — no workload pods scheduled here.
#   Workload pool: autoscaling enabled, receives all application workloads.
#   Both pools use node labels to enable scheduling affinity.
#
# Identity:
#   Cluster-level: SystemAssigned (manages cluster infrastructure — load balancers, etc.)
#   Workload-level: UserAssigned identities from foundation tier, referenced per service.

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-taskflow"
  resource_group_name = local.rg_name
  location            = var.location
  dns_prefix          = "aks-taskflow"

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                         = "system"
    node_count                   = 1
    vm_size                      = "Standard_D2s_v3"
    vnet_subnet_id               = local.snet_aks_id
    os_disk_size_gb              = 30
    type                         = "VirtualMachineScaleSets"
    only_critical_addons_enabled = true
    temporary_name_for_rotation  = "systmp"

    node_labels = {
      "nodepool-type" = "system"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    service_cidr        = "172.16.0.0/16"
    dns_service_ip      = "172.16.0.10"
    outbound_type       = "userAssignedNATGateway"
  }

  api_server_access_profile {
    authorized_ip_ranges = var.authorized_ip_ranges
  }

  oms_agent {
    log_analytics_workspace_id = local.law_id
  }

  depends_on = [azurerm_subnet_nat_gateway_association.aks]

  tags = local.common_tags
}

# TODO: implement azurerm_kubernetes_cluster_node_pool.workload
resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_D2s_v3"
  vnet_subnet_id        = local.snet_aks_id
  os_disk_size_gb       = 30
  mode                  = "User"

  auto_scaling_enabled = true
  min_count            = 1
  max_count            = 3

  node_labels = {
    "nodepool-type" = "workload"
  }

  tags = local.common_tags
}
