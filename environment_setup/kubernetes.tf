variable "aksServicePrincipalId" {
  type = string
}

variable "aksServicePrincipalSecret" {
  type = string
}

# Key Vault

resource "azurerm_key_vault" "aks" {
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

resource "random_id" "workspace" {
  keepers = {
    # Generate a new id each time we switch to a new resource group
    group_name = azurerm_resource_group.aml.name
  }

  byte_length = 8
}

resource "azurerm_log_analytics_workspace" "aks" {
  name                = "k8s-workspace-${random_id.workspace.hex}"
  location            = azurerm_resource_group.aml.location
  resource_group_name = azurerm_resource_group.aml.name
  sku                 = "PerGB2018"
}

resource "azurerm_log_analytics_solution" "aks" {
  solution_name         = "ContainerInsights"
  location              = azurerm_resource_group.aml.location
  resource_group_name   = azurerm_resource_group.aml.name
  workspace_resource_id = azurerm_log_analytics_workspace.aks.id
  workspace_name        = azurerm_log_analytics_workspace.aks.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}


# Kubernetes Service

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks${var.prefix}"
  location            = azurerm_resource_group.aml.location
  resource_group_name = azurerm_resource_group.aml.name
  dns_prefix          = "aks${var.prefix}"

  agent_pool_profile {
    name            = "default"
    count           = 6
    vm_size         = "Standard_D2_v2"
    os_type         = "Linux"
    os_disk_size_gb = 30
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
}

output "client_certificate" {
  value = azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.aks.kube_config_raw
}

resource "null_resource" "save-kube-config" {
    triggers = {
        config = azurerm_kubernetes_cluster.aks.kube_config_raw
    }
    provisioner "local-exec" {
        command = "mkdir -p ${path.module}/.kube && umask 077 && echo '${azurerm_kubernetes_cluster.aks.kube_config_raw}' > ${path.module}/.kube/azure_config"
    }
}
 

# Namespace

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

resource "kubernetes_namespace" "istio" {
  metadata {
    name = "istio-system"
  }
}

resource "kubernetes_secret" "istio_grafana" {
  metadata {
    name = "grafana"
    namespace = "istio-system"
    labels = {
      app = "grafana"
    }
  }
  data = {
    username = "admin"
    passphrase = "P4ssw0rd"
  }
}

resource "kubernetes_secret" "istio_kiali" {
  metadata {
    name = "kiali"
    namespace = "istio-system"
    labels = {
      app = "kiali"
    }
  }
  data = {
    username = "admin"
    passphrase = "P4ssw0rd"
  }
}

# Istio

resource "null_resource" "install-istio" {
    triggers = {
        workspace = null_resource.save-kube-config.id
        manifest = sha1(file("istio.aks.yaml"))
    }
    provisioner "local-exec" {
        command = "istioctl --kubeconfig ${path.module}/.kube/azure_config manifest apply -f istio.aks.yaml"
    }
}

# Connect Azure ML to AKS

resource "null_resource" "attach-azureml-aks" {
    triggers = {
        workspace = lookup(azurerm_template_deployment.aml.outputs, "id")
        cluster_id = azurerm_kubernetes_cluster.aks.id
    }
    provisioner "local-exec" {
        command = <<BASH
set -euxo pipefail
state=$(az ml computetarget detach -g ${azurerm_resource_group.aml.name} -w ${lookup(azurerm_template_deployment.aml.outputs, "name")} -n aks --query provisioningState -o tsv 2>/dev/null || true)
if [ "$state" == "Failed" ]; then
  az ml computetarget detach -g ${azurerm_resource_group.aml.name} -w ${lookup(azurerm_template_deployment.aml.outputs, "name")} -n aks 
fi
if [ "$state" == "Failed" ] || [ "$state" == "" ]; then
  az ml computetarget attach aks --compute-resource-id ${azurerm_kubernetes_cluster.aks.id} --name aks -g ${azurerm_resource_group.aml.name} -w ${lookup(azurerm_template_deployment.aml.outputs, "name")}
fi
BASH
    }
    depends_on = [
      kubernetes_namespace.istio,
      kubernetes_secret.istio_grafana,
      kubernetes_secret.istio_kiali,
    ]
}
 



