output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "devops_subnet_id" {
  value = azurerm_subnet.devops.id
}
