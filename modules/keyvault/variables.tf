
variable "location" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }
variable "current_user_object_id" { type = string }
variable "key_vault_sku" { type = string }
variable "cmk_key_size" { type = number }
variable "sql_server_identity_object_id" {
  description = "Object ID of the SQL server's system-assigned managed identity."
  type        = string
}
