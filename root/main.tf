
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "hub" {
  name     = "rg-${var.project}-hub-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "spoke" {
  name     = "rg-${var.project}-spoke-${var.environment}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "security" {
  name     = "rg-${var.project}-security-${var.environment}"
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Module: Network
# Creates Hub VNet, Workload Spoke VNet, subnets, peering, private DNS zones.
# ---------------------------------------------------------------------------
module "network" {
  source = "../../modules/network"

  location    = var.location
  project     = var.project
  environment = var.environment
  tags        = var.tags

  hub_resource_group_name   = azurerm_resource_group.hub.name
  spoke_resource_group_name = azurerm_resource_group.spoke.name

  hub_vnet_cidr            = var.hub_vnet_cidr
  hub_gateway_subnet_cidr  = var.hub_gateway_subnet_cidr
  hub_firewall_subnet_cidr = var.hub_firewall_subnet_cidr
  hub_bastion_subnet_cidr  = var.hub_bastion_subnet_cidr

  spoke_vnet_cidr                          = var.spoke_vnet_cidr
  spoke_appgw_subnet_cidr                  = var.spoke_appgw_subnet_cidr
  spoke_appservice_integration_subnet_cidr = var.spoke_appservice_integration_subnet_cidr
  spoke_private_endpoint_subnet_cidr       = var.spoke_private_endpoint_subnet_cidr
}

# ---------------------------------------------------------------------------
# Module: Hybrid Connectivity
# VPN Gateway in Hub VNet + Local Network Gateway + S2S connection.
# ---------------------------------------------------------------------------
module "hybrid_connectivity" {
  source = "../../modules/hybrid-connectivity"

  location                   = var.location
  project                    = var.project
  environment                = var.environment
  tags                       = var.tags
  resource_group_name        = azurerm_resource_group.hub.name
  gateway_subnet_id          = module.network.hub_gateway_subnet_id
  vpn_gateway_sku            = var.vpn_gateway_sku
  on_premises_public_ip      = var.on_premises_public_ip
  on_premises_address_spaces = var.on_premises_address_spaces
  vpn_shared_key             = var.vpn_shared_key
}

# ---------------------------------------------------------------------------
# Module: Key Vault
# Key Vault + CMK for SQL TDE. Must come before database module.
# ---------------------------------------------------------------------------
module "keyvault" {
  source = "../../modules/keyvault"

  location              = var.location
  project               = var.project
  environment           = var.environment
  tags                  = var.tags
  resource_group_name   = azurerm_resource_group.security.name
  tenant_id             = var.tenant_id
  current_user_object_id = var.current_user_object_id
  key_vault_sku         = var.key_vault_sku
  cmk_key_size          = var.cmk_key_size

  # Grant SQL managed identity access after SQL module creates it.
  sql_server_identity_object_id = module.database.sql_server_identity_object_id
}

# ---------------------------------------------------------------------------
# Module: Database
# SQL Logical Server + Database + Private Endpoint + TDE + CMK.
# ---------------------------------------------------------------------------
module "database" {
  source = "../../modules/database"

  location            = var.location
  project             = var.project
  environment         = var.environment
  tags                = var.tags
  resource_group_name = azurerm_resource_group.spoke.name

  sql_admin_login    = var.sql_admin_login
  sql_admin_password = var.sql_admin_password
  sql_database_sku   = var.sql_database_sku
  sql_max_size_gb    = var.sql_max_size_gb

  private_endpoint_subnet_id  = module.network.spoke_private_endpoint_subnet_id
  private_dns_zone_sql_id     = module.network.private_dns_zone_sql_id
  spoke_vnet_id               = module.network.spoke_vnet_id

  key_vault_key_id            = module.keyvault.cmk_key_id
  key_vault_id                = module.keyvault.key_vault_id
}

# ---------------------------------------------------------------------------
# Module: Compute
# App Service Plans, BFF App, Middleware App, Managed Identities,
# VNet Integration, Private Endpoints, App Settings.
# ---------------------------------------------------------------------------
module "compute" {
  source = "../../modules/compute"

  location            = var.location
  project             = var.project
  environment         = var.environment
  tags                = var.tags
  resource_group_name = azurerm_resource_group.spoke.name

  app_service_plan_sku               = var.app_service_plan_sku
  bff_app_name_suffix                = var.bff_app_name_suffix
  middleware_app_name_suffix         = var.middleware_app_name_suffix
  dotnet_version                     = var.dotnet_version

  vnet_integration_subnet_id         = module.network.spoke_appservice_integration_subnet_id
  private_endpoint_subnet_id         = module.network.spoke_private_endpoint_subnet_id
  private_dns_zone_app_services_id   = module.network.private_dns_zone_app_services_id
  spoke_vnet_id                      = module.network.spoke_vnet_id

  sql_connection_string              = module.database.sql_private_fqdn
  middleware_private_fqdn            = module.compute.middleware_private_fqdn
}

# ---------------------------------------------------------------------------
# Module: Ingress (Application Gateway WAF v2)
# Public entry point — WAF, TLS termination, routing to BFF private endpoint.
# ---------------------------------------------------------------------------
module "ingress" {
  source = "../../modules/ingress"

  location            = var.location
  project             = var.project
  environment         = var.environment
  tags                = var.tags
  resource_group_name = azurerm_resource_group.spoke.name

  appgw_subnet_id          = module.network.spoke_appgw_subnet_id
  appgw_sku_tier           = var.appgw_sku_tier
  appgw_capacity           = var.appgw_capacity

  bff_private_ip_address   = module.compute.bff_private_endpoint_ip
  bff_private_fqdn         = module.compute.bff_private_fqdn
  backend_hostname         = var.backend_hostname

  ssl_certificate_pfx_path = var.ssl_certificate_pfx_path
  ssl_certificate_password  = var.ssl_certificate_password
}
