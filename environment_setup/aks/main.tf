# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=1.36.1"
}

# Application Insights

resource "random_id" "workspace" {
  keepers = {
    # Generate a new id each time we switch to a new resource group
    group_name = var.resource_group_name
  }

  byte_length = 8
}

resource "azurerm_log_analytics_workspace" "aks" {
  name                = "k8s-workspace-${random_id.workspace.hex}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
}

resource "azurerm_log_analytics_solution" "aks" {
  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.aks.id
  workspace_name        = azurerm_log_analytics_workspace.aks.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

# Subnet permission

resource "azurerm_role_assignment" "aks_subnet" {
  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = var.aksServicePrincipalObjectId
}

# Kubernetes Service

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks${var.prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks${var.prefix}"

  agent_pool_profile {
    name            = "default"
    count           = 6
    vm_size         = "Standard_D2_v2"
    os_type         = "Linux"
    os_disk_size_gb = 30
    vnet_subnet_id  = var.subnet_id
  }

  addon_profile {
   oms_agent {
     enabled                    = true
     log_analytics_workspace_id = azurerm_log_analytics_workspace.aks.id
    }
  }

  service_principal {
    client_id     = var.aksServicePrincipalId
    client_secret = var.aksServicePrincipalSecret
  }

  depends_on = [
    azurerm_role_assignment.aks_subnet
  ]
}
