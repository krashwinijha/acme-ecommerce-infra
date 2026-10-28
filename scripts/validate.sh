#!/usr/bin/env bash
###############################################################################
# scripts/validate.sh
# Post-deployment validation script.
# Run this after `terraform apply` to verify the security boundaries.
#
# Requirements: az CLI, nslookup/dig, curl
# Run from a VM inside the spoke VNet (or via Bastion) for private DNS tests.
###############################################################################

set -euo pipefail

# ---- Load Terraform outputs ---------------------------------------------
echo "=== Loading Terraform outputs ==="
APPGW_IP=$(terraform output -raw application_gateway_public_ip)
BFF_FQDN=$(terraform output -raw bff_private_fqdn)
MIDDLEWARE_FQDN=$(terraform output -raw middleware_private_fqdn)
SQL_FQDN=$(terraform output -raw sql_server_fqdn)
KV_URI=$(terraform output -raw key_vault_uri)

echo "App Gateway IP : $APPGW_IP"
echo "BFF FQDN       : $BFF_FQDN"
echo "Middleware FQDN: $MIDDLEWARE_FQDN"
echo "SQL FQDN       : $SQL_FQDN"
echo "Key Vault URI  : $KV_URI"
echo ""

# ---- Test 1: BFF public hostname should be blocked ----------------------
echo "=== Test 1: BFF public access should be BLOCKED ==="
BFF_APP_NAME=$(terraform output -raw bff_private_fqdn | cut -d. -f1)
BFF_PUBLIC="https://${BFF_APP_NAME}.azurewebsites.net"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$BFF_PUBLIC" || echo "000")
if [[ "$HTTP_CODE" == "403" || "$HTTP_CODE" == "000" ]]; then
  echo "  PASS — BFF public access blocked (HTTP $HTTP_CODE)"
else
  echo "  FAIL — BFF public access returned HTTP $HTTP_CODE (expected 403 or connection refused)"
fi

# ---- Test 2: Middleware public hostname should be blocked ---------------
echo "=== Test 2: Middleware public access should be BLOCKED ==="
MW_APP_NAME=$(terraform output -raw middleware_private_fqdn | cut -d. -f1)
MW_PUBLIC="https://${MW_APP_NAME}.azurewebsites.net"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$MW_PUBLIC" || echo "000")
if [[ "$HTTP_CODE" == "403" || "$HTTP_CODE" == "000" ]]; then
  echo "  PASS — Middleware public access blocked (HTTP $HTTP_CODE)"
else
  echo "  FAIL — Middleware public access returned HTTP $HTTP_CODE"
fi

# ---- Test 3: Application Gateway should be reachable -------------------
echo "=== Test 3: Application Gateway public IP should respond ==="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 \
  -H "Host: shop.example.com" "https://$APPGW_IP" --insecure || echo "000")
echo "  App Gateway response: HTTP $HTTP_CODE (200-4xx expected; 000 = no route)"

# ---- Test 4: Private DNS resolution for BFF (run from inside VNet) ------
echo "=== Test 4: BFF private DNS resolution (requires execution from inside VNet) ==="
if command -v dig &>/dev/null; then
  BFF_IP=$(dig +short "$BFF_FQDN" @168.63.129.16 | tail -1)
  if [[ "$BFF_IP" =~ ^10\. ]]; then
    echo "  PASS — BFF resolves to private IP: $BFF_IP"
  else
    echo "  FAIL/SKIP — BFF resolved to: $BFF_IP (expected 10.x.x.x; run from inside VNet)"
  fi
else
  echo "  SKIP — dig not available; test from inside VNet using: nslookup $BFF_FQDN 168.63.129.16"
fi

# ---- Test 5: Private DNS resolution for SQL (run from inside VNet) ------
echo "=== Test 5: SQL private DNS resolution (requires execution from inside VNet) ==="
if command -v dig &>/dev/null; then
  SQL_IP=$(dig +short "$SQL_FQDN" @168.63.129.16 | tail -1)
  if [[ "$SQL_IP" =~ ^10\. ]]; then
    echo "  PASS — SQL resolves to private IP: $SQL_IP"
  else
    echo "  FAIL/SKIP — SQL resolved to: $SQL_IP (expected 10.x.x.x; run from inside VNet)"
  fi
else
  echo "  SKIP — Run from inside VNet: nslookup $SQL_FQDN 168.63.129.16"
fi

# ---- Test 6: SQL public endpoint should be inaccessible ----------------
echo "=== Test 6: SQL public endpoint TCP 1433 should be BLOCKED ==="
if command -v nc &>/dev/null; then
  if nc -z -w 5 "$SQL_FQDN" 1433 2>/dev/null; then
    echo "  FAIL — SQL public endpoint TCP 1433 is reachable (should be blocked)"
  else
    echo "  PASS — SQL public TCP 1433 connection refused/timed out"
  fi
else
  echo "  SKIP — nc not available; verify SQL public_network_access_enabled = false in Azure Portal"
fi

# ---- Test 7: Terraform idempotency check --------------------------------
echo "=== Test 7: Terraform plan should show no changes ==="
terraform plan -detailed-exitcode -out /dev/null 2>&1 | tail -5
EXIT_CODE=${PIPESTATUS[0]}
if [[ "$EXIT_CODE" == "0" ]]; then
  echo "  PASS — No infrastructure drift detected"
elif [[ "$EXIT_CODE" == "2" ]]; then
  echo "  WARN — Terraform plan shows changes; review before re-applying"
else
  echo "  FAIL — Terraform plan returned error code $EXIT_CODE"
fi

echo ""
echo "=== Validation complete ==="
echo "For SQL TDE+CMK verification, check Azure Portal:"
echo "  SQL Server > Transparent data encryption > Customer-managed key"
echo "For VPN connectivity test, check Azure Portal:"
echo "  VPN Gateway > Connections > Status = Connected"
