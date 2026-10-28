
output "sql_server_id" {
  value = azurerm_mssql_server.main.id
}

output "sql_server_fqdn" {
  description = "Public FQDN (used for reference only; public access is disabled)."
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}

output "sql_private_fqdn" {
  description = "Private FQDN resolved via privatelink.database.windows.net DNS zone."
  value       = "${azurerm_mssql_server.main.name}.database.windows.net"
}

output "sql_database_name" {
  value = azurerm_mssql_database.main.name
}

output "sql_server_identity_object_id" {
  description = "Object ID of the SQL server system-assigned managed identity. Passed to keyvault module for RBAC."
  value       = azurerm_mssql_server.main.identity[0].principal_id
}

output "sql_private_endpoint_id" {
  value = azurerm_private_endpoint.sql.id
}
