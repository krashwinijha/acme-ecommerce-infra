
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "pip-vpngw-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

# Optional: Second public IP for active-active configuration
resource "azurerm_public_ip" "vpn_gateway_secondary" {
  name                = "pip-vpngw-${var.project}-${var.environment}-secondary"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "vgw-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.vpn_gateway_sku
  generation          = "Generation1"
  # Set to true for active-active redundancy (requires VpnGw1 or higher)
  active_active = false
  enable_bgp    = true
  tags          = var.tags

  ip_configuration {
    name                          = "vgw-ipconfig-primary"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.gateway_subnet_id
  }

  bgp_settings {
    asn = 65515  # Azure default ASN; must not overlap with on-premises ASN
  }

  # Deployment can take 20-45 minutes.
}

# Local Network Gateway — represents the on-premises VPN device
resource "azurerm_local_network_gateway" "on_premises" {
  name                = "lgw-onprem-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  gateway_address     = var.on_premises_public_ip
  address_space       = var.on_premises_address_spaces
  tags                = var.tags

  bgp_settings {
    asn                 = 65000  # On-premises ASN — update to match actual device
    bgp_peering_address = "169.254.21.1"  # Update to match on-prem BGP peer IP
  }
}

# Site-to-Site IPsec Connection
resource "azurerm_virtual_network_gateway_connection" "s2s" {
  name                = "con-s2s-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.on_premises.id

  shared_key  = var.vpn_shared_key
  enable_bgp  = true

  ipsec_policy {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS2048"
    sa_lifetime      = 27000
    sa_datasize      = 102400000
  }
}

