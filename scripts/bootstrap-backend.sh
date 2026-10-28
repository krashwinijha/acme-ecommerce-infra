#!/usr/bin/env bash
###############################################################################
# scripts/bootstrap-backend.sh
# Run ONCE before `terraform init` to create the remote state storage.
# This script is intentionally separate from Terraform to avoid the
# circular dependency of "Terraform needs state to manage state storage".
###############################################################################

set -euo pipefail

SUBSCRIPTION_ID="${1:-}"
LOCATION="westeurope"
RG_NAME="rg-tfstate-acme"
SA_NAME="stacmetfstate001"   # Must be globally unique; change if taken
CONTAINER_NAME="tfstate"

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "Usage: $0 <subscription-id>"
  exit 1
fi

echo "=== Setting subscription ==="
az account set --subscription "$SUBSCRIPTION_ID"

echo "=== Creating resource group: $RG_NAME ==="
az group create \
  --name "$RG_NAME" \
  --location "$LOCATION" \
  --output table

echo "=== Creating storage account: $SA_NAME ==="
az storage account create \
  --name "$SA_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2 \
  --https-only true \
  --output table

echo "=== Enabling versioning and soft-delete on storage account ==="
az storage account blob-service-properties update \
  --account-name "$SA_NAME" \
  --resource-group "$RG_NAME" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30 \
  --output table

echo "=== Creating state container: $CONTAINER_NAME ==="
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$SA_NAME" \
  --auth-mode login \
  --output table

echo ""
echo "=== Bootstrap complete ==="
echo "State storage account : $SA_NAME"
echo "Container             : $CONTAINER_NAME"
echo ""
echo "Next steps:"
echo "  1. Update backend.tf with storage_account_name = \"$SA_NAME\""
echo "  2. Run: terraform init"
echo "  3. Copy terraform.tfvars.example to terraform.tfvars and fill in values"
echo "  4. Run: terraform plan"
echo "  5. Run: terraform apply"
