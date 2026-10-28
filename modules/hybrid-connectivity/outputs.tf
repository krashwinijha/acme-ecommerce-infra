
output "vpn_gateway_id" {
  value = azurerm_virtual_network_gateway.vpn.id
}

output "vpn_gateway_public_ip" {
  value = azurerm_public_ip.vpn_gateway.ip_address
}

output "s2s_connection_id" {
  value = azurerm_virtual_network_gateway_connection.s2s.id
}
