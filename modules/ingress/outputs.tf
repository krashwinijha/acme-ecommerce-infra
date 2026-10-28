

output "appgw_id" {
  value = azurerm_application_gateway.main.id
}

output "appgw_public_ip" {
  description = "Public IP of the Application Gateway. Create an A record for your domain pointing here."
  value       = azurerm_public_ip.appgw.ip_address
}

output "appgw_public_fqdn" {
  description = "Auto-assigned Azure FQDN for the App Gateway public IP."
  value       = azurerm_public_ip.appgw.fqdn
}

output "waf_policy_id" {
  value = azurerm_web_application_firewall_policy.main.id
}
