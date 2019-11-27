output "kube_config" {
  value = azurerm_kubernetes_cluster.aks.kube_config_raw
}

output "id" {
  value = azurerm_kubernetes_cluster.aks.id
}

output "location" {
  value = azurerm_kubernetes_cluster.aks.location
}
