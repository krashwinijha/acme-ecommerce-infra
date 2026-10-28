

variable "location" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }
variable "resource_group_name" { type = string }
variable "app_service_plan_sku" { type = string }
variable "bff_app_name_suffix" { type = string }
variable "middleware_app_name_suffix" { type = string }
variable "dotnet_version" { type = string }
variable "vnet_integration_subnet_id" { type = string }
variable "private_endpoint_subnet_id" { type = string }
variable "private_dns_zone_app_services_id" { type = string }
variable "spoke_vnet_id" { type = string }
variable "sql_connection_string" {
  description = "Private FQDN of the SQL server for connection string construction."
  type        = string
}
variable "middleware_private_fqdn" {
  description = "Private FQDN of the Middleware App Service (used by BFF app settings)."
  type        = string
  default     = "" # Will be populated after middleware is created; use depends_on in practice
}
