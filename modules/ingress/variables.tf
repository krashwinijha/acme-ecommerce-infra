

variable "location" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }
variable "resource_group_name" { type = string }
variable "appgw_subnet_id" { type = string }
variable "appgw_sku_tier" { type = string }
variable "appgw_capacity" { type = number }
variable "bff_private_ip_address" {
  description = "Private IP of the BFF private endpoint."
  type        = string
}
variable "bff_private_fqdn" {
  description = "Private FQDN of the BFF App Service for SNI and host header matching."
  type        = string
}
variable "backend_hostname" {
  description = "Public hostname (e.g. shop.example.com) for App Gateway HTTPS listener."
  type        = string
}
variable "ssl_certificate_pfx_path" {
  type    = string
  default = ""
}
variable "ssl_certificate_password" {
  type      = string
  sensitive = true
  default   = ""
}
