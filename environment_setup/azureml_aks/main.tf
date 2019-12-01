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
state=$(az ml computetarget show -g ${var.resource_group_name} -w ${var.azureml_workspace_name} -n ${var.compute_target_name} --query provisioningState -o tsv 2>/dev/null || true)
if [ "$state" == "Failed" ]; then
  az ml computetarget detach -g ${var.resource_group_name} -w ${var.azureml_workspace_name} -n ${var.compute_target_name} 
fi
if [ "$state" == "Failed" ] || [ "$state" == "" ]; then
  # There currently no "--load-balancer-type" option in "az ml computetarget attach aks", so we issue a REST call directly.
  # Tracking this in https://github.com/Azure/azure-cli-extensions/issues/1127
  loadBalancerSubnetProperty=""
  if [ "${var.load_balancer_type}" == "InternalLoadBalancer" ]; then
    loadBalancerSubnetProperty=', "loadBalancerSubnet": "'${var.aks_subnet_name}'"'
  fi
  az rest --method PUT --uri 'https://management.azure.com${var.azureml_workspace_id}/computes/${var.compute_target_name}?api-version=2019-11-01' --headers "Content-Type=application/json"  --body '{"location": "${var.aks_location}", "properties": {"computeType": "AKS", "resourceId": "${var.aks_id}", "properties": {"loadBalancerType": "${var.load_balancer_type}" '$loadBalancerSubnetProperty'}}}'
  state=""
  for i in $(seq 1 ${var.creation_timeout_s}); do
    state=$(az ml computetarget show -g ${var.resource_group_name} -w ${var.azureml_workspace_name} -n ${var.compute_target_name} --query provisioningState -o tsv)
    if [ $state != "Creating" ]; then
      break
    fi
    sleep 1
  done
  if [ $state != "Succeeded" ]; then
    echo "Provisioning state: $state"
    exit 1
  fi
fi
BASH
    }
}
