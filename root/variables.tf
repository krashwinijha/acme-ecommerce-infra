
# ---------------------------------------------------------------------------
# Identity & Subscription
# ---------------------------------------------------------------------------
variable "subscription_id" {
  description = "Azure subscription ID where all resources will be deployed."
  type        = string
}

variable "tenant_id" {
  description = "Azure Active Directory tenant ID."
  type        = string
}

variable "current_user_object_id" {
  description = "Object ID of the user/SP running Terraform — used for Key Vault admin access."
  type        = string
}

# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------
variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "environment" {
  description = "Deployment environment label (e.g. dev, staging, prod)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "project" {
  description = "Project identifier used in resource names."
  type        = string
  default     = "acme"
}

variable "tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
  default = {
    project     = "acme-ecommerce"
    environment = "prod"
    managed_by  = "terraform"
    owner       = "cloud-team"
  }
}

# ---------------------------------------------------------------------------
# Networking — Hub VNet
# ---------------------------------------------------------------------------
variable "hub_vnet_cidr" {
  description = "Address space for the Hub VNet."
  type        = string
  default     = "10.0.0.0/16"
}

variable "hub_gateway_subnet_cidr" {
  description = "CIDR for GatewaySubnet in the Hub VNet. Must be named 'GatewaySubnet'."
  type        = string
  default     = "10.0.0.0/27"
}

variable "hub_firewall_subnet_cidr" {
  description = "CIDR for AzureFirewallSubnet in the Hub VNet (reserved for future Firewall)."
  type        = string
  default     = "10.0.1.0/26"
}

variable "hub_bastion_subnet_cidr" {
  description = "CIDR for AzureBastionSubnet (reserved, /26 minimum)."
  type        = string
  default     = "10.0.2.0/26"
}

# ---------------------------------------------------------------------------
# Networking — Workload Spoke VNet
# ---------------------------------------------------------------------------
variable "spoke_vnet_cidr" {
  description = "Address space for the Workload Spoke VNet."
  type        = string
  default     = "10.1.0.0/16"
}

variable "spoke_appgw_subnet_cidr" {
  description = "CIDR for Application Gateway WAF v2 subnet."
  type        = string
  default     = "10.1.0.0/24"
}

variable "spoke_appservice_integration_subnet_cidr" {
  description = "CIDR for App Service VNet Integration (delegated) subnet."
  type        = string
  default     = "10.1.1.0/24"
}

variable "spoke_private_endpoint_subnet_cidr" {
  description = "CIDR for Private Endpoint subnet (BFF, Middleware, SQL)."
  type        = string
  default     = "10.1.2.0/24"
}

# ---------------------------------------------------------------------------
# Hybrid Connectivity
# ---------------------------------------------------------------------------
variable "vpn_gateway_sku" {
  description = "SKU for the Azure VPN Gateway. VpnGw1 supports active-active."
  type        = string
  default     = "VpnGw1"
}

variable "on_premises_public_ip" {
  description = "Public IP of the on-premises VPN device."
  type        = string
  default     = "203.0.113.10" # Replace with actual on-premises device IP
}

variable "on_premises_address_spaces" {
  description = "On-premises address spaces routed over the VPN tunnel."
  type        = list(string)
  default     = ["192.168.0.0/16"]
}

variable "vpn_shared_key" {
  description = "Pre-shared key for the Site-to-Site VPN connection. Supply via TF_VAR_vpn_shared_key."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------
variable "key_vault_sku" {
  description = "Key Vault SKU. Use 'premium' for HSM-backed keys in production."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku)
    error_message = "key_vault_sku must be 'standard' or 'premium'."
  }
}

variable "cmk_key_size" {
  description = "RSA key size in bits for the Customer-Managed Key."
  type        = number
  default     = 2048
}

# ---------------------------------------------------------------------------
# Azure SQL Database
# ---------------------------------------------------------------------------
variable "sql_admin_login" {
  description = "SQL Server administrator login name."
  type        = string
  default     = "sqladmin"
}

variable "sql_admin_password" {
  description = "SQL Server administrator password. Supply via TF_VAR_sql_admin_password."
  type        = string
  sensitive   = true
}

variable "sql_database_sku" {
  description = "SQL Database SKU name (e.g. GP_Gen5_2 for General Purpose, Basic for dev)."
  type        = string
  default     = "GP_Gen5_2"
}

variable "sql_max_size_gb" {
  description = "Maximum database size in GB."
  type        = number
  default     = 32
}

# ---------------------------------------------------------------------------
# App Service
# ---------------------------------------------------------------------------
variable "app_service_plan_sku" {
  description = "App Service Plan SKU. P1v3 (Premium v3) recommended for private endpoint support."
  type        = string
  default     = "P1v3"
}

variable "bff_app_name_suffix" {
  description = "Suffix for BFF App Service name (must be globally unique)."
  type        = string
  default     = "bff"
}

variable "middleware_app_name_suffix" {
  description = "Suffix for Middleware App Service name (must be globally unique)."
  type        = string
  default     = "middleware"
}

variable "dotnet_version" {
  description = "ASP.NET Core runtime version. NOTE: .NET 7 is EOL; upgrade to .NET 8."
  type        = string
  default     = "v8.0"
}

# ---------------------------------------------------------------------------
# Application Gateway
# ---------------------------------------------------------------------------
variable "appgw_sku_tier" {
  description = "Application Gateway WAF tier. WAF_v2 is required for OWASP rule sets."
  type        = string
  default     = "WAF_v2"
}

variable "appgw_capacity" {
  description = "Static capacity (instance count) for Application Gateway."
  type        = number
  default     = 2
}

variable "ssl_certificate_pfx_path" {
  description = "Path to the PFX file for HTTPS listener TLS termination. Leave empty to use self-signed (dev only)."
  type        = string
  default     = ""
}

variable "ssl_certificate_password" {
  description = "Password for the PFX certificate. Supply via TF_VAR_ssl_certificate_password."
  type        = string
  sensitive   = true
  default     = ""
}

variable "backend_hostname" {
  description = "Custom hostname for the BFF application (e.g. shop.example.com)."
  type        = string
  default     = "shop.example.com"
}
