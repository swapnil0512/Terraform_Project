provider "azurerm" {
   features {
      resource_group {
       prevent_deletion_if_contains_resources = false
     }
   }
}

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.115.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.14.1"
    }
  }
}

resource "azurerm_resource_group" "testaks" {
    name = var.resource_group_name
    location = var.region
}

resource "azurerm_virtual_network" "testaks" {
  name                = "my-vnet1"
  location            = azurerm_resource_group.testaks.location
  resource_group_name = azurerm_resource_group.testaks.name
  address_space       = ["10.0.0.0/16"]
  tags = {
    env = var.env
  }
  
}

resource "azurerm_subnet" "testaks" {
  name                 = "Testsubnet"
  resource_group_name  = azurerm_resource_group.testaks.name
  virtual_network_name = azurerm_virtual_network.testaks.name
  address_prefixes     = ["10.0.0.0/19"]
}

resource "azurerm_subnet" "testaks1" {
  name                 = "Testsubnet1"
  resource_group_name  = azurerm_resource_group.testaks.name
  virtual_network_name = azurerm_virtual_network.testaks.name
  address_prefixes     = ["10.0.32.0/19"]
}

# resource "azurerm_user_assigned_identity" "base" {
#   name                = "base"
#   location            = azurerm_resource_group.testaks.location
#   resource_group_name = azurerm_resource_group.testaks.name
# }

# resource "azurerm_role_assignment" "base" {
#   scope                = azurerm_resource_group.testaks.id
#   role_definition_name = "Network Contributor"
#   principal_id         = azurerm_user_assigned_identity.base.principal_id
# }

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.env}-${var.aks_name}"
  location            = azurerm_resource_group.testaks.location
  resource_group_name = azurerm_resource_group.testaks.name
  dns_prefix          = "devaks1"
  kubernetes_version = var.aks_version
  role_based_access_control_enabled = true
  automatic_channel_upgrade = "stable"
  private_cluster_enabled = false
  node_resource_group = "${var.resource_group_name}-${var.env}-${var.aks_name}"
  sku_tier = "Free"
  oidc_issuer_enabled = true
  workload_identity_enabled = true

  network_profile {
    network_plugin = "azure"
    dns_service_ip = "10.0.64.10"
    service_cidr = "10.0.64.0/19"
  }

  default_node_pool {
    name                         = "aks"
    vm_size                      = "Standard_D4ds_v5"
    os_disk_size_gb              = 30
    vnet_subnet_id               = azurerm_subnet.testaks.id
    orchestrator_version         = var.aks_version
    type                         = "VirtualMachineScaleSets"
    enable_node_public_ip = true
    enable_auto_scaling = true
    node_count = 2
    min_count = 2
    max_count = 10
    node_labels = {
      role = "general"
    }
  }

  identity { 
    type = "SystemAssigned"
  }
  
  tags = {
     env = "var.env"
    }

  #  lifecycle {
  #   ignore_changes = ["default_node_pool[0].node_count"]
  # }

  # depends_on = ["azurerm_role_assignment.base"]
}

# resource "azurerm_kubernetes_cluster_node_pool" "spot" {
#   name                  = "spot"
#   kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
#   vm_size               = "Standard_d2_v3"
#   node_count            = 1
#   vnet_subnet_id = azurerm_subnet.testaks.id
#   orchestrator_version = var.aks_version
#   priority = "Spot"
#   spot_max_price = -1
#   eviction_policy = "Delete"

#   enable_auto_scaling = true
#   min_count = 1
#   max_count = 10

#   node_labels = {
#     role = "spot"
#     "kubernetes.azure.com/scalesetpriority" = "spot"
#   }

#   node_taints = [
#     "spot:NoSchedule",
#     "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
#   ]

#   tags = {
#     env = var.env
#   }

  # lifecycle {
  #   ignore_changes = ["node_count"]
  #}
# }

# # Storage Account
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "LRS"
  enable_https_traffic_only = true
  tags = {
    name = "tf-backend"
  }
}

# Storage Container for Terraform State
resource "azurerm_storage_container" "aks" {
  name                  = "terraform-container"
  storage_account_name  = var.storage_account_name
  container_access_type = "private"
}
