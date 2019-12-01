# azure-mlops-terraform
 MLOps with Azure ML, Terraform and Azure DevOps multi-stage pipelines

## About this project

This project automatically deploys DevOps infrastructure and Azure ML infrastructure to build, train and deploy a basic ML model to Azure Kubernetes Service.

![DevOps pipeline](/docs/images/pipeline.png)

This project adapts the MLOpsPython solution (see References) with the following improvements to increase developer productivity.
* Added Terraform scripts to deploy Azure ML workspace and AKS cluster in a VNET.
* Deploy AML model with Internal Load Balancer (not exposed through a Public IP), and select the subnet where the ILB is deployed.
* Reduced number of Azure DevOps variables.
* Cleaner organization of scripts.
* Single multi-stage pipeline in version control, rather than separate release pipeline. A release pipeline is not only hard to version control, but also requires **two** separate inbound artifacts from the build pipeline (the pipeline artifacts + the ML Model), which creates an opportunity to introduce errors.
* Pass specific trained model version when triggering model deployment, rather than just deploying the latest model.
* Added smoke test to validate the deployed image on AKS.
* Use self-hosted DevOps agent to build. These agents are also deployed with Terraform. Motivation:
  * If you build on Microsoft-hosted agents, the build has to download the entire mcr.microsoft.com/mlops/python container image at every stage, which takes about 2 minutes. With a 2-stage build pipeline, that's 4 minutes overhead per build, which you incur only the first time by using a self-hosted agent VM. The solution provision 4 agents on a single VM, which can lead to side effects, but I've found this to be appropriate for "client-server" job that do little local processing and mostly call out to cloud APIs.
  * As the ML model is exposed through an Internal Load Balancer with a VNET internal address, this allows reaching the service directly from the agent (to run smoke tests), without having to spin a container. This saves a little bit of time and complexity.

## How-to

### Set up the Azure DevOps environment

* Create an Azure DevOps project. Take note of the Azure DevOps organization in the URL, e.g. https://dev.azure.com/{MyOrg}.
* In Azure DevOps, create a Personal Access Token (PAT), the URL is at https://dev.azure.com/{MyOrg}/_usersSettings/tokens. Grant the token the permission Agent Pools > Read & manage.
* In Azure DevOps, create an Agent Pool. Name the pool `pool001`. (If you choose another name, you will need to set the variable in Terraform, and also update the DevOps pipeline YAML).
* Install the [Azure DevOps Machine Learning extension](https://marketplace.visualstudio.com/items?itemName=ms-air-aiagility.vss-services-azureml) into your Azure DevOps organization.

### Required resources

If you don't yet have a public SSH key defined in ~/.ssh/id_rsa.pub, run:
```
ssh-keygen
```

Install the Azure CLI and log in to your subscription:

```
az login
az account list -o table
```

If you don't want to use the default subscription, set a different one using:

```
az account set -s {subscriptionId}
```

Create a Service Principal that will serve as the identity of the created AKS cluster. Make sure to use `--skip-assignment true`, otherwise the principal will be granted Contributor permission to your entire subscription.

```
az ad sp create-for-rbac --skip-assignment true
```

The command outputs the principal ID (`appId`) and secret (`password`), which we will use in the next command.

Now we will also need the service principal Object ID. Retrieve this with this command, passing the principal ID:

```
az ad sp show --id {createdPrincipalId} --query objectId
```

Example:

```
az ad sp create-for-rbac --skip-assignment true
{
  "appId": "5a6da102-1de4-47b6-8e3a-628e26f075e6",
  "displayName": "azure-cli-2019-11-26-17-31-58",
  "name": "http://azure-cli-2019-11-26-17-31-58",
  "password": "ffffffff-0000-0000-0000-cd226c638d82",
  "tenant": "72f988bf-86f1-41af-91ab-2d7cd011db47"
}

az ad sp show --id  5a6da102-1de4-47b6-8e3a-628e26f075e6 --query objectId
"58270c2e-2c3d-4473-aadb-faffdb106b44"
```

### Terraform deployment

Deploy the Terraform environment. Choose a prefix containing only lowercase letters and numbers. The prefix must be globally unique as it's used for DNS names, so use something original!

```
cd environment_setup
terraform plan -out=out.tfstate -var prefix=xyzzy01 -var pat={AzureDevOpsPATToken} -var sshkey="$(cat ~/.ssh/id_rsa.pub)" -var url=https://dev.azure.com/{MyOrg} -var aksServicePrincipalId={createdPrincipalId} -var aksServicePrincipalSecret={createdPrincipalSecret} -var aksServicePrincipalObjectId={createdPrincipalObjectId}
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

The first run, or any subsequent run where the model performance improves, will result in the model being registered and deployed to AKS:

![DevOps pipeline](/docs/images/pipeline.png)

Any subsequent run where the model performance does not improve, will result in the pipeline being canceled:

![DevOps pipeline](/docs/images/pipeline_canceled.png)

## References

* [Create an Azure DevOps agent with Terraform](https://melcher.dev/2019/02/create-an-azure-devops-build/release-agent-with-terraform-ubuntu-edition/)
* [MLOpsPython: MLOps using Azure ML Services and Azure DevOps](https://github.com/microsoft/MLOpsPython)
