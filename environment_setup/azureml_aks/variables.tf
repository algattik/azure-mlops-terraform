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
variable "aks_subnet_name" {
  type    = string
}
variable "load_balancer_type" {
  type    = string
  default = "PublicIp"
  description = "Load balancer type of AKS cluster. Valid values are PublicIp and InternalLoadBalancer"
}
variable "compute_target_name" {
  type    = string
  default = "aks"
}
variable "creation_timeout_s" {
  type    = number
  default = 1200
}
