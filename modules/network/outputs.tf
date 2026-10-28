###############################################################################
# modules/network/outputs.tf
###############################################################################

output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "hub_gateway_subnet_id" {
  value = azurerm_subnet.hub_gateway.id
}

output "spoke_vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "spoke_appgw_subnet_id" {
  value = azurerm_subnet.spoke_appgw.id
}

output "spoke_appservice_integration_subnet_id" {
  value = azurerm_subnet.spoke_appservice_integration.id
}

output "spoke_private_endpoint_subnet_id" {
  value = azurerm_subnet.spoke_private_endpoint.id
}

output "private_dns_zone_app_services_id" {
  value = azurerm_private_dns_zone.app_services.id
}

output "private_dns_zone_sql_id" {
  value = azurerm_private_dns_zone.sql.id
}

output "private_dns_zone_keyvault_id" {
  value = azurerm_private_dns_zone.keyvault.id
}
