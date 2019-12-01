# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=1.36.1"
}

# Create virtual network
resource "azurerm_virtual_network" "aml" {
  name                = "vnet-${var.prefix}"
  address_space       = ["10.100.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Create subnet
resource "azurerm_subnet" "aks" {
  # Name currently MUST be `aks-subnet` to deploy Azure ML internal load balancer, as the AML compute creation loadBalancerSubnet argument
  #  is ignored by the Azure ML API as of November 2019.
  name                 = "aks-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.aml.name
  address_prefix       = "10.100.1.0/24"
  #Avoid update after AKS sets up routing
  #https://github.com/terraform-providers/terraform-provider-azurerm/issues/3749#issuecomment-532849895
  lifecycle {
    ignore_changes = [route_table_id]
  }
}

# Create subnet
resource "azurerm_subnet" "devops" {
  name                 = "devops-agents-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.aml.name
  address_prefix       = "10.100.2.0/24"
}
