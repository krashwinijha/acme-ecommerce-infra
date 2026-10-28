
resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "main" {
  name                = "kv-${var.project}-${var.environment}-${random_string.kv_suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = var.key_vault_sku
  tags                = var.tags

  
  soft_delete_retention_days = 90
  purge_protection_enabled   = true


  enable_rbac_authorization = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"

    # Allow access from spoke VNet (for App Services and SQL via private endpoint)
    # For full private-only access, remove ip_rules and use private endpoint only.
    ip_rules = []
    virtual_network_subnet_ids = []
  }
}


resource "azurerm_role_assignment" "kv_admin_deployer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.current_user_object_id
}


resource "azurerm_role_assignment" "kv_sql_crypto_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = var.sql_server_identity_object_id

  # Ensure SQL managed identity exists before assigning role.
  depends_on = [azurerm_key_vault.main]
}


resource "azurerm_key_vault_key" "sql_cmk" {
  name         = "cmk-sql-tde-${var.environment}"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = var.cmk_key_size
  tags         = var.tags

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  # Key rotation policy — rotate every 90 days, notify 30 days before expiry.
  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }

    expire_after         = "P90D"
    notify_before_expiry = "P29D"
  }

  # Key must only be created after the admin role assignment takes effect.
  depends_on = [azurerm_role_assignment.kv_admin_deployer]
}

