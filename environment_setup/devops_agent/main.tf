# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=1.36.1"
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
  source                 = "./devops_agent/devops_agent_init.sh"
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
    subnet_id                     = var.subnet_id
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
  name                 = "install_azure_devops_agent"
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
