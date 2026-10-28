

variable "location" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }
variable "resource_group_name" { type = string }
variable "sql_admin_login" { type = string }
variable "tenant_id" { type = string }
variable "sql_admin_password" {
  type      = string
  sensitive = true
}
variable "sql_database_sku" { type = string }
variable "sql_max_size_gb" { type = number }
variable "private_endpoint_subnet_id" { type = string }
variable "private_dns_zone_sql_id" { type = string }
variable "spoke_vnet_id" { type = string }
variable "key_vault_key_id" {
  description = "Versionless Key ID of the CMK in Key Vault."
  type        = string
}
variable "key_vault_id" { type = string }
