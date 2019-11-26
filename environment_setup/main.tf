# Deploy a Resource Group with an Azure ML Workspace and supporting resources.
#
# For naming conventions, refer to:
#   https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging

# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=1.36.1"
}

# Data

data "azurerm_client_config" "current" {}

# Resource Group

resource "azurerm_resource_group" "aml" {
  name     = "rg-${var.prefix}-ml"
  location = var.location
}


module "vnet" {
  source = "./vnet"
  resource_group_name = azurerm_resource_group.aml.name
  prefix = var.prefix
  location = var.location
}

module "devops_agent" {
  source = "./devops_agent"
  subnet_id = module.vnet.devops_subnet_id
  prefix = var.prefix
  location = var.location
  url = var.url
  pat = var.pat
  pool = var.pool
  agent = var.agent
  sshkey = var.sshkey
  size = var.size
}

module "aks" {
  source = "./aks"
  prefix = var.prefix
  location = var.location
  resource_group_name = azurerm_resource_group.aml.name
  tenant_id = data.azurerm_client_config.current.tenant_id
  subnet_id = module.vnet.aks_subnet_id
  aksServicePrincipalId = var.aksServicePrincipalId
  aksServicePrincipalSecret = var.aksServicePrincipalSecret
  aksServicePrincipalObjectId = var.aksServicePrincipalObjectId
}

module "azureml" {
  source = "./azureml"
  prefix = var.prefix
  location = var.location
  tenant_id = data.azurerm_client_config.current.tenant_id
  resource_group_name = azurerm_resource_group.aml.name
}

module "azureml_aks" {
  source = "./azureml_aks"
  azureml_workspace_id = module.azureml.id
  resource_group_name = azurerm_resource_group.aml.name
  azureml_workspace_name = module.azureml.name
  aks_id = module.aks.id
  kube_config = module.aks.kube_config
}
