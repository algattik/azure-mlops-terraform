variable "prefix" {
  type = string
}

variable "aksServicePrincipalId" {
  type = string
}

variable "aksServicePrincipalSecret" {
  type = string
}

variable "aksServicePrincipalObjectId" {
  type = string
}

variable "location" {
  type    = string
  default = "West Europe"
}

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
variable "num_agents" {
  type = number
  description = "Specify the number of agents, e.g. '2'. Agents will be named with a random prefix."
  default = 4
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

variable "load_balancer_type" {
  type    = string
  default = "PublicIp"
  description = "Load balancer type of AKS cluster. Valid values are PublicIp and InternalLoadBalancer"
}
