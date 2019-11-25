# Deploy a Resource Group with an Azure ML Workspace and supporting resources.
#
# For naming conventions, refer to:
#   https://docs.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging

# Inputs

variable "prefix" {
  type = string
}

variable "location" {
  type    = string
  default = "West Europe"
}

# Data

data "azurerm_client_config" "current" {}

# Resource Group

resource "azurerm_resource_group" "aml" {
  name     = "rg-${var.prefix}-ml"
  location = var.location
}

# Storage Account

resource "azurerm_storage_account" "aml" {
  name                     = "st${var.prefix}"
  resource_group_name      = azurerm_resource_group.aml.name
  location                 = azurerm_resource_group.aml.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Key Vault

resource "azurerm_key_vault" "aml" {
  name                     = "kv-${var.prefix}"
  location                    = azurerm_resource_group.aml.location
  resource_group_name         = azurerm_resource_group.aml.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id

  sku_name = "standard"

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

# Application Insights

resource "azurerm_application_insights" "aml" {
  name                     = "appinsights-${var.prefix}"
  resource_group_name      = azurerm_resource_group.aml.name
  location                 = azurerm_resource_group.aml.location
  application_type    = "web"
}

output "instrumentation_key" {
  value = azurerm_application_insights.aml.instrumentation_key
}

output "app_id" {
  value = azurerm_application_insights.aml.app_id
}

# Container Registry

resource "azurerm_container_registry" "aml" {
  name                     = "acr${var.prefix}"
  resource_group_name      = azurerm_resource_group.aml.name
  location                 = azurerm_resource_group.aml.location
  sku                      = "Standard"
  admin_enabled            = true
}

# Azure ML Workspace

resource "azurerm_template_deployment" "aml" {
  name                     = "aml-${var.prefix}-deploy"
  resource_group_name = azurerm_resource_group.aml.name

  template_body = <<DEPLOY
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "type": "string"
    },
    "amlWorkspaceName": {
      "type": "string"
    },
    "storageAccount": {
      "type": "string"
    },
    "keyVault": {
      "type": "string"
    },
    "applicationInsights": {
      "type": "string"
    },
    "containerRegistry": {
      "type": "string"
    }
  },
  "resources": [
    {
      "type": "Microsoft.MachineLearningServices/workspaces",
      "apiVersion": "2018-11-19",
      "name": "[parameters('amlWorkspaceName')]",
      "location": "[parameters('location')]",
      "identity": {
        "type": "systemAssigned"
      },
      "properties": {
        "friendlyName": "[parameters('amlWorkspaceName')]",
        "keyVault": "[parameters('keyVault')]",
        "applicationInsights": "[parameters('applicationInsights')]",
        "containerRegistry": "[parameters('containerRegistry')]",
        "storageAccount": "[parameters('storageAccount')]"
      }
    }
  ],
  "outputs": {
    "id": {
      "type": "string",
      "value": "[resourceId('Microsoft.MachineLearningServices/workspaces', parameters('amlWorkspaceName'))]"
    },
    "name": {
      "type": "string",
      "value": "[parameters('amlWorkspaceName')]"
    }
  }
}
DEPLOY

  parameters = {
    location = azurerm_resource_group.aml.location
    amlWorkspaceName = "aml-${var.prefix}"
    storageAccount = azurerm_storage_account.aml.id
    keyVault = azurerm_key_vault.aml.id
    applicationInsights = azurerm_application_insights.aml.id
    containerRegistry = azurerm_container_registry.aml.id
  }

  deployment_mode = "Incremental"
}
