
resource "azurerm_public_ip" "appgw" {
  name                = "pip-appgw-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  domain_name_label   = "appgw-${var.project}-${var.environment}"
  tags                = var.tags
}

##############################################################################
# WAF Policy — OWASP 3.2
##############################################################################
resource "azurerm_web_application_firewall_policy" "main" {
  name                = "waf-policy-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"   # Use "Detection" initially, then switch to Prevention
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }

    managed_rule_set {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.0"
    }
  }

  custom_rules {
    name      = "RateLimitRule"
    priority  = 1
    rule_type = "RateLimitRule"
    action    = "Block"

    rate_limit_duration          = "OneMin"
    rate_limit_threshold         = 100
    group_rate_limit_by          = "ClientAddr"

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }
      operator           = "IPMatch"
      negation_condition = true
      match_values       = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    }
  }
}

##############################################################################
# Application Gateway WAF v2
##############################################################################
locals {
  # Names used internally by App Gateway configuration
  backend_pool_name            = "backend-pool-bff"
  frontend_port_https_name     = "frontend-port-443"
  frontend_port_http_name      = "frontend-port-80"
  frontend_ip_config_name      = "frontend-ip-public"
  http_listener_https_name     = "listener-https"
  http_listener_http_name      = "listener-http"
  backend_http_settings_name   = "backend-settings-bff"
  routing_rule_https_name      = "routing-rule-https"
  routing_rule_redirect_name   = "routing-rule-http-redirect"
  redirect_config_name         = "redirect-http-to-https"
  health_probe_name            = "probe-bff-health"
  ssl_cert_name                = "ssl-cert-main"
}

resource "azurerm_application_gateway" "main" {
  name                = "appgw-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
  firewall_policy_id  = azurerm_web_application_firewall_policy.main.id

  sku {
    name     = var.appgw_sku_tier
    tier     = var.appgw_sku_tier
    capacity = var.appgw_capacity
  }

  # Autoscaling (alternative to static capacity)
  # autoscale_configuration {
  #   min_capacity = 2
  #   max_capacity = 10
  # }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.appgw_subnet_id
  }

  # ---- Frontend -------------------------------------------------------
  frontend_ip_configuration {
    name                 = local.frontend_ip_config_name
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  frontend_port {
    name = local.frontend_port_https_name
    port = 443
  }

  frontend_port {
    name = local.frontend_port_http_name
    port = 80
  }

  # ---- SSL Certificate ------------------------------------------------
  dynamic "ssl_certificate" {
    for_each = var.ssl_certificate_pfx_path != "" ? [1] : []
    content {
      name     = local.ssl_cert_name
      data     = filebase64(var.ssl_certificate_pfx_path)
      password = var.ssl_certificate_password
    }
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"  # TLS 1.2+ only
  }

  # ---- Backend Pool — BFF Private Endpoint ----------------------------
  backend_address_pool {
    name         = local.backend_pool_name
    # Use IP address of BFF private endpoint for reliable routing
    ip_addresses = [var.bff_private_ip_address]
  }

  # ---- Backend HTTP Settings ------------------------------------------
  backend_http_settings {
    name                                = local.backend_http_settings_name
    cookie_based_affinity               = "Disabled"
    port                                = 443
    protocol                            = "Https"
    request_timeout                     = 60
    pick_host_name_from_backend_address = false
    host_name                           = var.bff_private_fqdn

    probe_name = local.health_probe_name

    trusted_root_certificate_names = []
  }

  # ---- Health Probe ---------------------------------------------------
  probe {
    name                                      = local.health_probe_name
    protocol                                  = "Https"
    path                                      = "/health"
    host                                      = var.bff_private_fqdn
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false
    minimum_servers                           = 0

    match {
      status_code = ["200-399"]
    }
  }

  # ---- HTTPS Listener -------------------------------------------------
  http_listener {
    name                           = local.http_listener_https_name
    frontend_ip_configuration_name = local.frontend_ip_config_name
    frontend_port_name             = local.frontend_port_https_name
    protocol                       = "Https"
    host_name                      = var.backend_hostname
    ssl_certificate_name           = var.ssl_certificate_pfx_path != "" ? local.ssl_cert_name : null
    firewall_policy_id             = azurerm_web_application_firewall_policy.main.id
    require_sni                    = true
  }

  # ---- HTTP Listener (for redirect only) ------------------------------
  http_listener {
    name                           = local.http_listener_http_name
    frontend_ip_configuration_name = local.frontend_ip_config_name
    frontend_port_name             = local.frontend_port_http_name
    protocol                       = "Http"
    host_name                      = var.backend_hostname
  }

  # ---- HTTP -> HTTPS Redirect -----------------------------------------
  redirect_configuration {
    name                 = local.redirect_config_name
    redirect_type        = "Permanent"
    target_listener_name = local.http_listener_https_name
    include_path         = true
    include_query_string = true
  }

  # ---- Routing Rules --------------------------------------------------
  request_routing_rule {
    name                        = local.routing_rule_redirect_name
    priority                    = 100
    rule_type                   = "Basic"
    http_listener_name          = local.http_listener_http_name
    redirect_configuration_name = local.redirect_config_name
  }

  request_routing_rule {
    name                       = local.routing_rule_https_name
    priority                   = 200
    rule_type                  = "Basic"
    http_listener_name         = local.http_listener_https_name
    backend_address_pool_name  = local.backend_pool_name
    backend_http_settings_name = local.backend_http_settings_name
  }

  # ---- WAF Configuration (attached via firewall_policy_id) -----------
  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  depends_on = [azurerm_web_application_firewall_policy.main]
}
