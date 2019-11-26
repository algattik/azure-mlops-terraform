output "instrumentation_key" {
  value = azurerm_application_insights.aml.instrumentation_key
}

output "app_id" {
  value = azurerm_application_insights.aml.app_id
}

output "id" {
  value = azurerm_template_deployment.aml.outputs["id"]
}

output "name" {
  value = azurerm_template_deployment.aml.outputs["name"]
}
