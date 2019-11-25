variable "url" {
  type = string
  description = "Specify the Azure DevOps url e.g. https://dev.azure.com/myorg"
}

variable "pat" {
  type = string
  description = "Provide a Personal Access Token (PAT) for Azure DevOps. Create it at https://dev.azure.com/[Organization]/_usersSettings/tokens with permission Agent Pools > Read & manage"
}

variable "pool" {
  type = string
  description = "Specify the name of the agent pool - must exist before. Create it at https://dev.azure.com/[Organization]/_settings/agentpools"
  default = "pool001"
}

#The name of the agent
variable "agent" {
  type = string
  description = "Specify the name of the agent(s), space separated"
  default = "agent001 agent002 agent003 agent004"
}

variable "sshkey" {
  type    = string
  description = "Provide a ssh public key to logon to the VM"
}

variable "size" {
  type    = string
  description = "Specify the size of the VM"
  default = "Standard_D2s_v3"
}

resource "azurerm_resource_group" "devops" {
  name     = "rg-${var.prefix}-devops"
  location = var.location
}

resource "azurerm_storage_account" "devops" {
  name                     = "stdevops${var.prefix}"
  resource_group_name      = azurerm_resource_group.devops.name
  location                 = azurerm_resource_group.devops.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "devops" {
  name                  = "content"
  storage_account_name  = azurerm_storage_account.devops.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "devops" {
  name                   = "devops_agent_init.sh"
  storage_account_name   = azurerm_storage_account.devops.name
  storage_container_name = azurerm_storage_container.devops.name
  type                   = "Block"
  source                 = "devops_agent_init.sh"
}

data "azurerm_storage_account_blob_container_sas" "devops_agent_init" {
  connection_string = azurerm_storage_account.devops.primary_connection_string
  container_name    = azurerm_storage_container.devops.name
  https_only        = true

  start  = "2000-01-01"
  expiry = "2099-01-01"

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = false
  }
}


# Create virtual network
resource "azurerm_virtual_network" "devops" {
  name                = "AzureDevOpsVnet"
  address_space       = ["10.100.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.devops.name
}

# Create subnet
resource "azurerm_subnet" "devops" {
  name                 = "AzureDevopsSubnet"
  resource_group_name  = azurerm_resource_group.devops.name
  virtual_network_name = azurerm_virtual_network.devops.name
  address_prefix       = "10.100.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "devops" {
  name                = "AzureDevOpsPublicIP"
  location            = var.location
  resource_group_name = azurerm_resource_group.devops.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "devops" {
  name                = "AzureDevOpsNetworkSecurityGroup"
  location            = var.location
  resource_group_name = azurerm_resource_group.devops.name
}

# Create network interface
resource "azurerm_network_interface" "devops" {
  name                      = "AzureDevOpsNIC"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.devops.name
  network_security_group_id = azurerm_network_security_group.devops.id

  ip_configuration {
    name                          = "AzureDevOpsNicConfiguration"
    subnet_id                     = azurerm_subnet.devops.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.devops.id
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "devops" {
  name                  = "AzureDevOps"
  location              = var.location
  resource_group_name   = azurerm_resource_group.devops.name
  network_interface_ids = [azurerm_network_interface.devops.id]
  vm_size               = var.size

  storage_os_disk {
    name              = "AzureDevOpsOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "AzureDevOps"
    admin_username = "azuredevopsuser"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/azuredevopsuser/.ssh/authorized_keys"
      key_data = var.sshkey
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = azurerm_storage_account.devops.primary_blob_endpoint
  }
}

resource "azurerm_virtual_machine_extension" "devops" {
  name                 = "hostname"
  location             = var.location
  resource_group_name  = azurerm_resource_group.devops.name
  virtual_machine_name = azurerm_virtual_machine.devops.name
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  #timestamp: use this field only to trigger a re-run of the script by changing value of this field.
  #           Any integer value is acceptable; it must only be different than the previous value.
  settings = jsonencode({
  "timestamp" : 1
  })
  protected_settings = jsonencode({
  "fileUris": ["${azurerm_storage_blob.devops.url}${data.azurerm_storage_account_blob_container_sas.devops_agent_init.sas}"],
  "commandToExecute": "bash devops_agent_init.sh '${var.url}' '${var.pat}' '${var.pool}' '${var.agent}'"
  })
}
