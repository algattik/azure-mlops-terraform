output "aks_subnet_name" {
  value = azurerm_subnet.aks.name
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "devops_subnet_id" {
  value = azurerm_subnet.devops.id
}
