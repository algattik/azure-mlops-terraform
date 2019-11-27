variable "resource_group_name" {
  type    = string
}
variable "aks_location" {
  type    = string
}
variable "kube_config" {
  type    = string
}
variable "azureml_workspace_id" {
  type    = string
}
variable "azureml_workspace_name" {
  type    = string
}
variable "aks_id" {
  type    = string
}
variable "load_balancer_type" {
  type    = string
  default = "InternalLoadBalancer"
}
