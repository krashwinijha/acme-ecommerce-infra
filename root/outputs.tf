###############################################################################
# outputs.tf  (root module)
# Expose non-sensitive resource identifiers useful for validation and handover.
###############################################################################

output "hub_vnet_id" {
  description = "Resource ID of the Hub VNet."
  value       = module.network.hub_vnet_id
}

output "spoke_vnet_id" {
  description = "Resource ID of the Workload Spoke VNet."
  value       = module.network.spoke_vnet_id
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the Azure VPN Gateway."
  value       = module.hybrid_connectivity.vpn_gateway_public_ip
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault."
  value       = module.keyvault.key_vault_uri
}

output "sql_server_fqdn" {
  description = "Private FQDN of the SQL logical server (resolved only within the VNet via Private DNS)."
  value       = module.database.sql_private_fqdn
}

output "bff_private_fqdn" {
  description = "Private FQDN of the BFF App Service."
  value       = module.compute.bff_private_fqdn
}

output "middleware_private_fqdn" {
  description = "Private FQDN of the Middleware App Service."
  value       = module.compute.middleware_private_fqdn
}

output "application_gateway_public_ip" {
  description = "Public IP address of the Application Gateway WAF v2. Point DNS here."
  value       = module.ingress.appgw_public_ip
}

output "bff_managed_identity_client_id" {
  description = "Client ID of the BFF Managed Identity (for downstream RBAC assignments)."
  value       = module.compute.bff_managed_identity_client_id
}

output "middleware_managed_identity_client_id" {
  description = "Client ID of the Middleware Managed Identity."
  value       = module.compute.middleware_managed_identity_client_id
}
