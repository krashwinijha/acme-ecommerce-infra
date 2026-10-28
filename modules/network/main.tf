###############################################

##############################################################################
# Hub VNet + Subnets
##############################################################################
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.project}-hub-${var.environment}"
  location            = var.location
  resource_group_name = var.hub_resource_group_name
  address_space       = [var.hub_vnet_cidr]
  tags                = var.tags
}

# GatewaySubnet — required name for VPN/ExpressRoute gateway
resource "azurerm_subnet" "hub_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.hub_resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_gateway_subnet_cidr]
  # No NSG allowed on GatewaySubnet by Azure policy
}

# AzureFirewallSubnet — reserved for future Azure Firewall
resource "azurerm_subnet" "hub_firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.hub_resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_firewall_subnet_cidr]
}

# AzureBastionSubnet — reserved for Azure Bastion (/26 or larger)
resource "azurerm_subnet" "hub_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.hub_resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_bastion_subnet_cidr]
}

##############################################################################
# Workload Spoke VNet + Subnets
##############################################################################
resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.project}-spoke-${var.environment}"
  location            = var.location
  resource_group_name = var.spoke_resource_group_name
  address_space       = [var.spoke_vnet_cidr]
  tags                = var.tags
}

# ---- Application Gateway subnet (WAF v2) --------------------------------
resource "azurerm_subnet" "spoke_appgw" {
  name                 = "snet-appgw"
  resource_group_name  = var.spoke_resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.spoke_appgw_subnet_cidr]
}

resource "azurerm_network_security_group" "appgw" {
  name                = "nsg-appgw-${var.environment}"
  location            = var.location
  resource_group_name = var.spoke_resource_group_name
  tags                = var.tags

  # Azure infrastructure communication (required by App Gateway)
  security_rule {
    name                       = "Allow-AppGW-Infrastructure"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS-Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP-Inbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-AzureLoadBalancer"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "appgw" {
  subnet_id                 = azurerm_subnet.spoke_appgw.id
  network_security_group_id = azurerm_network_security_group.appgw.id
}

# ---- App Service VNet Integration subnet (outbound, delegated) ----------
resource "azurerm_subnet" "spoke_appservice_integration" {
  name                 = "snet-appservice-integration"
  resource_group_name  = var.spoke_resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.spoke_appservice_integration_subnet_cidr]

  delegation {
    name = "app-service-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_network_security_group" "appservice_integration" {
  name                = "nsg-appservice-int-${var.environment}"
  location            = var.location
  resource_group_name = var.spoke_resource_group_name
  tags                = var.tags

  # Allow App Service outbound to Private Endpoint subnet
  security_rule {
    name                       = "Allow-Outbound-To-PrivateEndpoints"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "1433"]
    source_address_prefix      = var.spoke_appservice_integration_subnet_cidr
    destination_address_prefix = var.spoke_private_endpoint_subnet_cidr
  }

  security_rule {
    name                       = "Allow-Outbound-To-AzureServices"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }
}

resource "azurerm_subnet_network_security_group_association" "appservice_integration" {
  subnet_id                 = azurerm_subnet.spoke_appservice_integration.id
  network_security_group_id = azurerm_network_security_group.appservice_integration.id
}

# ---- Private Endpoint subnet --------------------------------------------
resource "azurerm_subnet" "spoke_private_endpoint" {
  name                 = "snet-private-endpoints"
  resource_group_name  = var.spoke_resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.spoke_private_endpoint_subnet_cidr]

  # Required to allow NSG on private endpoint subnet
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_network_security_group" "private_endpoint" {
  name                = "nsg-private-endpoint-${var.environment}"
  location            = var.location
  resource_group_name = var.spoke_resource_group_name
  tags                = var.tags

  # Allow HTTPS from App Gateway subnet to BFF private endpoint
  security_rule {
    name                       = "Allow-HTTPS-From-AppGW"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.spoke_appgw_subnet_cidr
    destination_address_prefix = var.spoke_private_endpoint_subnet_cidr
  }

  # Allow HTTPS from App Service Integration subnet to App Service private endpoints
  security_rule {
    name                       = "Allow-HTTPS-From-AppService"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.spoke_appservice_integration_subnet_cidr
    destination_address_prefix = var.spoke_private_endpoint_subnet_cidr
  }

  # Allow SQL from App Service Integration subnet to SQL private endpoint
  security_rule {
    name                       = "Allow-SQL-From-AppService"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = var.spoke_appservice_integration_subnet_cidr
    destination_address_prefix = var.spoke_private_endpoint_subnet_cidr
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "private_endpoint" {
  subnet_id                 = azurerm_subnet.spoke_private_endpoint.id
  network_security_group_id = azurerm_network_security_group.private_endpoint.id
}

##############################################################################
# VNet Peering — Hub <-> Spoke
##############################################################################
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-spoke"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true  # Hub gateway accessible from spoke
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke-to-hub"
  resource_group_name          = var.spoke_resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true  # Use hub's VPN/ER gateway for on-prem connectivity
  depends_on                   = [azurerm_virtual_network_peering.hub_to_spoke]
}

##############################################################################
# Private DNS Zones
##############################################################################

# --- Azure App Services ---
resource "azurerm_private_dns_zone" "app_services" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.spoke_resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "app_services_spoke" {
  name                  = "link-app-services-spoke"
  resource_group_name   = var.spoke_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.app_services.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "app_services_hub" {
  name                  = "link-app-services-hub"
  resource_group_name   = var.spoke_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.app_services.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}

# --- Azure SQL Database ---
resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = var.spoke_resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_spoke" {
  name                  = "link-sql-spoke"
  resource_group_name   = var.spoke_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_hub" {
  name                  = "link-sql-hub"
  resource_group_name   = var.spoke_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}

# --- Azure Key Vault ---
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.spoke_resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault_spoke" {
  name                  = "link-kv-spoke"
  resource_group_name   = var.spoke_resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags
}
