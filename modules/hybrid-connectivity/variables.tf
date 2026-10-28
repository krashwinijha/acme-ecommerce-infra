

variable "location" { type = string }
variable "project" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }
variable "resource_group_name" { type = string }
variable "gateway_subnet_id" { type = string }
variable "vpn_gateway_sku" { type = string }
variable "on_premises_public_ip" { type = string }
variable "on_premises_address_spaces" { type = list(string) }
variable "vpn_shared_key" {
  type      = string
  sensitive = true
}
