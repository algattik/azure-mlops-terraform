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
state=$(az ml computetarget show -g ${var.resource_group_name} -w ${var.azureml_workspace_name} -n aks --query provisioningState -o tsv 2>/dev/null || true)
if [ "$state" == "Failed" ]; then
  az ml computetarget detach -g ${var.resource_group_name} -w ${var.azureml_workspace_name} -n aks 
fi
if [ "$state" == "Failed" ] || [ "$state" == "" ]; then
  # There currently no "--load-balancer-type" option in "az ml computetarget attach aks", so we issue a REST call directly.
  # Note that this deployes the load balancer in a subnet called "aks-subnet".
  az rest --method PUT --uri 'https://management.azure.com${var.azureml_workspace_id}/computes/aks?api-version=2019-11-01' --body '{"location": "${var.aks_location}", "properties": {"computeType": "AKS", "resourceId": "${var.aks_id}", "properties": {"loadBalancerType":"${var.load_balancer_type}"}}}'

fi
BASH
    }
}
