# Acme E-Commerce — Azure Landing Zone: Implementation Plan

## Architecture Summary

Hub-and-Spoke topology in West Europe with:
- Application Gateway WAF v2 as the sole internet entry point
- BFF + Middleware App Services with private endpoints (public access disabled)
- Azure SQL Database with Private Endpoint + TDE + CMK via Key Vault
- VPN Gateway (primary) + ExpressRoute stub (secondary) for on-premises hybrid connectivity
- Modular Terraform with remote state on Azure Storage

## Module Structure

| Module | Resources |
|---|---|
| `network` | Hub VNet, Spoke VNet, Subnets, VNet Peering, Private DNS Zones |
| `hybrid-connectivity` | VPN Gateway, Local Network Gateway, S2S Connection |
| `keyvault` | Key Vault, CMK Key, Access Policies |
| `database` | SQL Logical Server, SQL Database, Private Endpoint, TDE CMK |
| `compute` | App Service Plans, BFF App, Middleware App, Managed Identities, VNet Integration, Private Endpoints |
| `ingress` | Application Gateway WAF v2, Public IP, Listeners, Routing Rules |

## Files to Create

- `versions.tf`, `providers.tf`, `backend.tf`, `variables.tf`, `main.tf`, `outputs.tf`
- `modules/network/`, `modules/hybrid-connectivity/`, `modules/keyvault/`, `modules/database/`, `modules/compute/`, `modules/ingress/`
- `terraform.tfvars`, `.gitignore`, `README.md`, `scripts/validate.sh`


Bonus:
1.	Name the concept where you position the applications/workloads in Azure/Cloud
Answer- Following Azure landing zone concept
2.	What would be the name of the networking structure we should use in the architecture above.
Answer- Use Hub-Spoke-Network Model Architecture

