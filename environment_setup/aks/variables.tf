variable "prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type    = string
}

variable "tenant_id" {
  type    = string
}

variable "subnet_id" {
  type    = string
}

variable "aksServicePrincipalId" {
  type = string
}

variable "aksServicePrincipalObjectId" {
  type = string
}

variable "aksServicePrincipalSecret" {
  type = string
}
