# Acme E-Commerce — Azure Landing Zone (Terraform)

Secure, private, hybrid-connected infrastructure for migrating the Acme Corporation e-commerce platform to **Azure West Europe** using a **Hub-and-Spoke** topology.

---

## Architecture Overview

```
Internet / Customers
        │ HTTPS (TCP 443)
        ▼
┌──────────────────────────────────────────┐
│  Azure Application Gateway WAF v2        │
│  Public IP · TLS termination · OWASP 3.2 │
└──────────────┬───────────────────────────┘
               │ Private Endpoint (HTTPS)
               ▼
┌──────────────────────────────────────────┐  Workload Spoke VNet (10.1.0.0/16)
│  BFF App Service (.NET 8)                │
│  Private Endpoint · VNet Integration     │
│  Public access DISABLED                  │
└──────────────┬───────────────────────────┘
               │ Private Endpoint (HTTPS) via VNet Integration
               ▼
┌──────────────────────────────────────────┐
│  Middleware App Service (.NET 8)         │
│  Private Endpoint · VNet Integration     │
│  Public access DISABLED                  │
└──────────────┬───────────────────────────┘
               │ Private Endpoint (TCP 1433) via VNet Integration
               ▼
┌──────────────────────────────────────────┐
│  Azure SQL Database                      │
│  Private Endpoint · TDE + CMK            │
│  Public network DISABLED                 │
└──────────────────────────────────────────┘

Hub VNet (10.0.0.0/16)
  ├── GatewaySubnet          (10.0.0.0/27)  — VPN Gateway
  ├── AzureFirewallSubnet    (10.0.1.0/26)  — Reserved
  └── AzureBastionSubnet     (10.0.2.0/26)  — Reserved

On-premises ←→ VPN Gateway (S2S IPsec + BGP) ←→ Hub VNet
```

---

## Project Structure

```
acme-ecommerce-infra/
├── versions.tf                        # Terraform + provider version constraints
├── providers.tf                       # Azure provider configuration
├── backend.tf                         # Remote state on Azure Blob Storage
├── variables.tf                       # All input variables
├── main.tf                            # Root module — composes all child modules
├── outputs.tf                         # Key resource identifiers
├── terraform.tfvars.example           # Template — copy to terraform.tfvars
├── .gitignore                         # Excludes state, secrets, local artifacts
├── modules/
│   ├── network/                       # VNets, subnets, NSGs, peering, DNS zones
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── hybrid-connectivity/           # VPN Gateway, LNG, S2S connection
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── keyvault/                      # Key Vault, CMK key, RBAC, rotation policy
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── database/                      # SQL Server, Database, Private Endpoint, TDE+CMK
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── compute/                       # App Service Plans, BFF, Middleware, Private Endpoints
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ingress/                       # Application Gateway WAF v2, WAF Policy
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── scripts/
    ├── bootstrap-backend.sh           # Create state storage (run ONCE before init)
    └── validate.sh                    # Post-deploy security validation
```

---

## Prerequisites

| Tool | Version |
|---|---|
| Terraform | >= 1.7.0 |
| Azure CLI | >= 2.60 |
| az subscription | Contributor + User Access Administrator |

```bash
# Verify tools
terraform version
az version

# Login
az login
az account set --subscription "<your-subscription-id>"

# Get your Object ID (needed for current_user_object_id variable)
az ad signed-in-user show --query id -o tsv
```

---

## Deployment Steps

### Step 1 — Bootstrap Remote State (run ONCE)

```bash
chmod +x scripts/bootstrap-backend.sh
./scripts/bootstrap-backend.sh <subscription-id>
```

### Step 2 — Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

Set sensitive values as environment variables (never in tfvars):

```bash
export TF_VAR_vpn_shared_key="<your-vpn-psk>"
export TF_VAR_sql_admin_password="<your-sql-password>"
export TF_VAR_ssl_certificate_password="<your-cert-password>"
```

### Step 3 — Initialize

```bash
terraform init
```

### Step 4 — Plan

```bash
terraform plan -out=tfplan.out
```

Review the plan carefully. VPN Gateway deployment takes 20-45 minutes.

### Step 5 — Apply

```bash
terraform apply tfplan.out
```

### Step 6 — Validate

```bash
chmod +x scripts/validate.sh
./scripts/validate.sh
```

> **Note:** For private DNS and SQL connectivity tests, run from a VM inside the VNet (or via Azure Bastion).

---

## DNS Configuration

After deployment, point your domain to the Application Gateway:

```
shop.example.com.  A  <application_gateway_public_ip output>
```

---

## Security Boundaries

| Component | Internet Accessible | Network Path |
|---|---|---|
| Application Gateway WAF | ✅ Yes (by design) | Public IP |
| BFF App Service | ❌ No | Private Endpoint only |
| Middleware App Service | ❌ No | Private Endpoint only |
| Azure SQL Database | ❌ No | Private Endpoint only |
| Key Vault | ❌ No | Azure Services bypass only |

---

## Known Limitations & Risks

1. **.NET 7 is EOL (May 2024)** — This Terraform uses .NET 8. Coordinate with app team.
2. **VPN Gateway provisioning** — Takes 20-45 minutes. Do not interrupt apply.
3. **CMK deletion risk** — If the CMK key is deleted or revoked, the SQL database becomes inaccessible. Ensure purge protection is enabled and access is monitored.
4. **App Service health checks** — Will show unhealthy until .NET application is deployed. This is expected.
5. **Application failover / regional DR** — Not in scope for this Terraform. Requires secondary region, SQL geo-replication, and Traffic Manager.
6. **ExpressRoute** — Stubbed in `modules/hybrid-connectivity/main.tf`. Uncomment when circuit is provisioned.
7. **Azure Bastion / Firewall** — Subnets reserved; resources not deployed to control costs.

---

## Cleanup

```bash
# Destroy all resources
terraform destroy

# Remove state storage (manual, since it's outside Terraform)
az group delete --name rg-tfstate-acme --yes
```

> ⚠️ Key Vault purge protection means the vault cannot be permanently deleted for 90 days after soft-delete.

---

## Estimated Monthly Cost (West Europe, Prod SKUs)

| Component | Approximate Cost |
|---|---|
| App Service Plan P1v3 × 2 | ~$140/month |
| Azure SQL GP_Gen5_2 | ~$370/month |
| Application Gateway WAF v2 (2 CU) | ~$350/month |
| VPN Gateway VpnGw1 | ~$270/month |
| Key Vault Standard | ~$5/month |
| Private DNS Zones × 3 | ~$3/month |

> Costs are estimates; actual cost depends on traffic, data processed, and reserved pricing.
