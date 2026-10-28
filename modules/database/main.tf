

# Unique suffix for SQL server name (globally unique)
resource "random_string" "sql_suffix" {
  length  = 6
  special = false
  upper   = false
}

##############################################################################
# SQL Logical Server
##############################################################################
resource "azurerm_mssql_server" "main" {
  name                = "sql-${var.project}-${var.environment}-${random_string.sql_suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = "12.0"
  tags                = var.tags

  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password

  # Disable public network access — all traffic via Private Endpoint only
  public_network_access_enabled = false

  # Minimum TLS version
  minimum_tls_version = "1.2"

  # System-assigned Managed Identity — required for CMK/TDE
  identity {
    type = "SystemAssigned"
  }

  # Microsoft Entra ID admin (recommended for production — enables AAD auth)
  # Update azuread_administrator block after setting up an Entra group.
  azuread_administrator {
    login_username              = "sql-aad-admin"
    object_id                   = var.sql_admin_login     # Replace with actual Entra object ID
    tenant_id                   = var.tenant_id
    azuread_authentication_only = false  # Set true to disable SQL auth (recommended in prod)
  }
}


# SQL Database

resource "azurerm_mssql_database" "main" {
  name         = "sqldb-${var.project}-${var.environment}"
  server_id    = azurerm_mssql_server.main.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = var.sql_max_size_gb
  sku_name     = var.sql_database_sku
  tags         = var.tags

  # Zone redundancy (requires Business Critical or Premium tier)
  # zone_redundant = true

  # Short-term backup retention (7 days default)
  short_term_retention_policy {
    retention_days           = 7
    backup_interval_in_hours = 12
  }

  # Long-term backup retention
  long_term_retention_policy {
    weekly_retention  = "P4W"
    monthly_retention = "P12M"
    yearly_retention  = "P5Y"
    week_of_year      = 1
  }
}

##############################################################################
# TDE with Customer-Managed Key
# CRITICAL: If CMK becomes inaccessible, the database becomes unavailable.
# Ensure Key Vault access, key rotation and soft-delete are correctly configured.
##############################################################################
resource "azurerm_mssql_server_transparent_data_encryption" "main" {
  server_id        = azurerm_mssql_server.main.id
  key_vault_key_id = var.key_vault_key_id

  # Depend on the SQL server having the CMK role assignment in Key Vault
  depends_on = [azurerm_mssql_server.main]
}

##############################################################################
# Private Endpoint — SQL
##############################################################################
resource "azurerm_private_endpoint" "sql" {
  name                = "pe-sql-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-sql-${var.project}-${var.environment}"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-sql"
    private_dns_zone_ids = [var.private_dns_zone_sql_id]
  }
}

##############################################################################
# SQL Firewall — deny all (belt-and-suspenders; private endpoint is primary)
##############################################################################
resource "azurerm_mssql_firewall_rule" "deny_all" {
  name             = "DenyAllPublic"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

##############################################################################
# SQL Auditing — store to Log Analytics (requires workspace in production)
##############################################################################
resource "azurerm_mssql_server_extended_auditing_policy" "main" {
  server_id                               = azurerm_mssql_server.main.id
  log_monitoring_enabled                  = true
  retention_in_days                       = 90
  storage_account_subscription_id         = null
  storage_endpoint                        = null
  storage_account_access_key              = null
  storage_account_access_key_is_secondary = false
}
