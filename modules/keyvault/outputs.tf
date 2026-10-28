
output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "cmk_key_id" {
  description = "Versionless Key ID used as TDE protector — avoids TDE outage on key rotation."
  # Using versionless ID means SQL will always use the latest key version.
  value = azurerm_key_vault_key.sql_cmk.versionless_id
}
