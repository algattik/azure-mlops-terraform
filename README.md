# azure-mlops-terraform
 MLOps with Azure ML, Terraform and Azure DevOps multi-stage pipelines

## About this project

This project adapts the MLOpsPython solution (see References) with the following improvements to increase developer productivity.
* Added Terraform scripts to deploy Azure ML workspace and AKS cluster.
* Reduced number of Azure DevOps variables.
* Cleaner organization of scripts.
* Use self-hosted DevOps agent to build. Motivation: if you build on Microsoft-hosted agents, the build has to download the entire mcr.microsoft.com/mlops/python container image at every stage, which takes about 2 minutes. With a 2-stage build pipeline, that's 4 minutes overhead per build, which you incur only the first time by using a self-hosted agent VM. The solution provision 4 agents on a single VM, which can lead to side effects, but I've found this to be appropriate for "client-server" job that do little local processing and mostly call out to cloud APIs.

## How-to

### Set up the Azure DevOps environment

* Create an Azure DevOps project. Take note of the Azure DevOps organization in the URL, e.g. https://dev.azure.com/{MyOrg}.
* In Azure DevOps, create a Personal Access Token (PAT), the URL is at https://dev.azure.com/{MyOrg}/_usersSettings/tokens. Grant the token the permission Agent Pools > Read & manage.
* In Azure DevOps, create an Agent Pool. Name the pool `pool001`. (If you choose another name, you will need to set the variable in Terraform, and also update the DevOps pipeline YAML).
* Install the [Azure DevOps Machine Learning extension](https://marketplace.visualstudio.com/items?itemName=ms-air-aiagility.vss-services-azureml) into your Azure DevOps organization.

### Provision Azure resources

If you don't yet have a public SSH key defined in ~/.ssh/id_rsa.pub, run:
```
ssh-keygen
```

Create a Service Principal that will serve as the identity of the created AKS cluster. Make sure to use `--skip-assignment true`, otherwise the principal will be granted Contributor permission to your entire subscription.

```
az ad sp create-for-rbac --skip-assignment true
```

The command outputs the principal ID and secret, which we will use in the next command.

Deploy the Terraform environment. Choose a prefix containing only lowercase letters and numbers. The prefix must be globally unique as it's used for DNS names, so use something original!

```
cd environment_setup
terraform plan -out=out.tfstate -var prefix=xyzzy01 -var pat={AzureDevOpsPATToken} -var sshkey="$(cat ~/.ssh/id_rsa.pub)" -var url=https://dev.azure.com/{MyOrg} -var aksServicePrincipalId={createdPrincipalId} -var aksServicePrincipalSecret={createdPrincipalSecret}
terraform apply out.tfstate
```

This will deploy two resource groups:
* rg-{prefix}-ml containing the Azure ML Workspace and support resources (Storage Account, Container Registry, Key Vault and Application Insights), and the AKS cluster and Log Analytics with Container Insights. Note that the AKS cluster has 12 cores, as this is required by Azure ML.
* rg-{prefix}-devops containing the Azure DevOps agent VM.

### Configure Azure DevOps service connection and Variable Group

* In Azure DevOps, go to Project settings > Service Connections. Create a new service connection of type _Azure Resource Manager_. Select _Service principal (automatic)_ and Scope level _Machine Learning Workspace_. Point to the Azure ML Workspace created by Terraform. Name your service connection `AzureMLWorkspace`.

* In Azure DevOps, go to Pipelines > Library and create a Variable Group. Name it `devopsforai-aml-vg`. Add the following variables, replacing {prefix} with the prefix you chose for Terraform:

| Variable name | value |
| -------------- | --------------- |
| RESOURCE_GROUP | rg-_{prefix}_-ml |
| WORKSPACE_NAME | aml-_{prefix}_ |
| WORKSPACE_SVC_CONNECTION | AzureMLWorkspace |
| skipComponentGovernanceDetection | true |

The `skipComponentGovernanceDetection` entry is useful only if you [work for Microsoft](https://aka.ms/cgdocs) (Microsoft internal link), to save additional time by disabling dependency scanning.

### Run Build pipeline

In Azure DevOps, create a new Build pipeline and point to `devops_pipelines/azdo-ci-build-train.yml`. Execute the pipeline.

The script devops_pipelines/azdo-ci-build-train.yml has a section commented out, to use the new new agentless ML job submission extension [Azure DevOps Machine Learning extension > Run published pipeline server task](https://marketplace.visualstudio.com/items?itemName=ms-air-aiagility.vss-services-azureml), but it's commented out and replaced by an agent-based version while I sort out blocking issues with the extension authors. (The job gets canceled instead of ending successfully).

### Create Release pipeline

Follow the instructions at https://github.com/microsoft/MLOpsPython/blob/master/docs/getting_started.md#set-up-a-release-deployment-pipeline-to-deploy-the-model. You can skip the deployment to ACI and deploy directly to AKS.

I've been hit by an [Azure CLI bug](https://github.com/Azure/azure-cli/issues/11379) which has forced me to come with a workaround:
Before the AzureML Model Deploy task, add a bash task with the following inline script:
```
echo "##vso[task.setvariable variable=HOME]${HOME:-$AGENT_HOMEDIRECTORY}"
```

I've found it useful to add a Smoke test task after the AzureML Model Deploy task. Create an Azure CLI task, select your `AzureMLWorkspace` service connection and enter the following inline script:
```
set -euo pipefail

az extension add -n azure-cli-ml

uri=$(az ml service show -g $RESOURCE_GROUP -w $WORKSPACE_NAME -n mlops-aks --query scoringUri -o tsv)
key=$(az ml service get-keys -g $RESOURCE_GROUP -w $WORKSPACE_NAME -n mlops-aks --query primaryKey -o tsv)

# jq -e will set exit code if element not found
curl -H "Authorization: Bearer $key" "$uri" -d '{"data":[[1,2,3,4,5,6,7,8,9,10],[10,9,8,7,6,5,4,3,2,1]]}' -H Content-type:application/json | jq -e .result
```


## References

* [Create an Azure DevOps agent with Terraform](https://melcher.dev/2019/02/create-an-azure-devops-build/release-agent-with-terraform-ubuntu-edition/)
* [MLOpsPython: MLOps using Azure ML Services and Azure DevOps](https://github.com/microsoft/MLOpsPython)
