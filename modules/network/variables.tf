###############################################################################
# modules/network/variables.tf
###############################################################################

variable "location" {
  type = string
}

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "hub_resource_group_name" {
  type = string
}

variable "spoke_resource_group_name" {
  type = string
}

variable "hub_vnet_cidr" {
  type = string
}

variable "hub_gateway_subnet_cidr" {
  type = string
}

variable "hub_firewall_subnet_cidr" {
  type = string
}

variable "hub_bastion_subnet_cidr" {
  type = string
}

variable "spoke_vnet_cidr" {
  type = string
}

variable "spoke_appgw_subnet_cidr" {
  type = string
}

variable "spoke_appservice_integration_subnet_cidr" {
  type = string
}

variable "spoke_private_endpoint_subnet_cidr" {
  type = string
}
