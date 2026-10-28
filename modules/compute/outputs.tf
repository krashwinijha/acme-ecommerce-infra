
output "bff_app_name" {
  value = azurerm_linux_web_app.bff.name
}

output "bff_private_fqdn" {
  description = "Private FQDN for the BFF App Service (resolved via privatelink DNS zone)."
  value       = "${azurerm_linux_web_app.bff.name}.privatelink.azurewebsites.net"
}

output "bff_private_endpoint_ip" {
  description = "Private IP address of the BFF private endpoint (for App Gateway backend pool)."
  value       = azurerm_private_endpoint.bff.private_service_connection[0].private_ip_address
}

output "bff_managed_identity_object_id" {
  value = azurerm_linux_web_app.bff.identity[0].principal_id
}

output "bff_managed_identity_client_id" {
  value = azurerm_linux_web_app.bff.identity[0].client_id
}

output "middleware_app_name" {
  value = azurerm_linux_web_app.middleware.name
}

output "middleware_private_fqdn" {
  description = "Private FQDN for the Middleware App Service."
  value       = "${azurerm_linux_web_app.middleware.name}.privatelink.azurewebsites.net"
}

output "middleware_managed_identity_object_id" {
  value = azurerm_linux_web_app.middleware.identity[0].principal_id
}

output "middleware_managed_identity_client_id" {
  value = azurerm_linux_web_app.middleware.identity[0].client_id
}
