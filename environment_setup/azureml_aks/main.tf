resource "null_resource" "save-kube-config" {
    triggers = {
        config = var.kube_config
    }
    provisioner "local-exec" {
        command = "mkdir -p ${path.module}/.kube && umask 077 && echo '${var.kube_config}' > ${path.module}/.kube/azure_config"
    }
}
 
# Connect Azure ML to AKS

resource "null_resource" "attach-azureml-aks" {
    triggers = {
        workspace = var.azureml_workspace_id
        cluster_id = var.aks_id
    }
    provisioner "local-exec" {
        command = <<BASH
set -euxo pipefail
state=$(az ml computetarget detach -g ${var.resource_group_name} -w ${var.azureml_workspace_name} -n aks --query provisioningState -o tsv 2>/dev/null || true)
if [ "$state" == "Failed" ]; then
  az ml computetarget detach -g ${var.resource_group_name} -w ${var.azureml_workspace_name} -n aks 
fi
if [ "$state" == "Failed" ] || [ "$state" == "" ]; then
  az ml computetarget attach aks --compute-resource-id ${var.aks_id} --name aks -g ${var.resource_group_name} -w ${var.azureml_workspace_name}
fi
BASH
    }
}
