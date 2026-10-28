
resource "azurerm_service_plan" "bff" {
  name                = "asp-${var.project}-bff-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  tags                = var.tags
}

resource "azurerm_service_plan" "middleware" {
  name                = "asp-${var.project}-middleware-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  tags                = var.tags
}

##############################################################################
# BFF App Service
##############################################################################
resource "azurerm_linux_web_app" "bff" {
  name                = "app-${var.project}-${var.bff_app_name_suffix}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.bff.id
  tags                = var.tags

  # Disable all public network access — traffic only via Private Endpoint
  public_network_access_enabled = false

  # Route ALL outbound traffic through VNet Integration (not just RFC-1918)
  virtual_network_subnet_id = var.vnet_integration_subnet_id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true

    application_stack {
      dotnet_version = var.dotnet_version
    }

    # Force HTTPS
    http2_enabled = true

    # Health check path (update when application is deployed)
    health_check_path = "/health"
  }

  app_settings = {
    # BFF calls Middleware via its private hostname
    "MIDDLEWARE_BASE_URL" = "https://${var.middleware_private_fqdn}"

    # Use Managed Identity to call downstream services (no passwords)
    "ASPNETCORE_ENVIRONMENT" = var.environment == "prod" ? "Production" : "Development"

    # Force all outbound traffic through VNet
    "WEBSITE_VNET_ROUTE_ALL" = "1"

    # DNS — use Azure DNS for private DNS resolution
    "WEBSITE_DNS_SERVER" = "168.63.129.16"

    # Disable ARR affinity (stateless apps don't need sticky sessions)
    "WEBSITE_ARR_AFFINITY" = "0"
  }

  logs {
    http_logs {
      retention_in_days = 30
    }
    application_logs {
      file_system_level = "Warning"
    }
  }
}


resource "azurerm_private_endpoint" "bff" {
  name                = "pe-bff-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-bff-${var.project}-${var.environment}"
    private_connection_resource_id = azurerm_linux_web_app.bff.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-bff"
    private_dns_zone_ids = [var.private_dns_zone_app_services_id]
  }
}

##############################################################################
# Middleware App Service
##############################################################################
resource "azurerm_linux_web_app" "middleware" {
  name                = "app-${var.project}-${var.middleware_app_name_suffix}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.middleware.id
  tags                = var.tags

  public_network_access_enabled = false

  # Route all outbound traffic through VNet Integration
  virtual_network_subnet_id = var.vnet_integration_subnet_id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = true

    application_stack {
      dotnet_version = var.dotnet_version
    }

    http2_enabled = true
    health_check_path = "/health"
  }

  app_settings = {
    # Middleware connects to SQL via private FQDN + managed identity
    # Connection string uses Managed Identity — no password needed
    "SQL_CONNECTION_STRING" = "Server=${var.sql_connection_string};Database=sqldb-${var.project}-${var.environment};Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;"

    "ASPNETCORE_ENVIRONMENT" = var.environment == "prod" ? "Production" : "Development"
    "WEBSITE_VNET_ROUTE_ALL" = "1"
    "WEBSITE_DNS_SERVER"     = "168.63.129.16"
    "WEBSITE_ARR_AFFINITY"   = "0"
  }

  logs {
    http_logs {
      retention_in_days = 30
    }
    application_logs {
      file_system_level = "Warning"
    }
  }
}

##############################################################################
# Middleware — Private Endpoint (inbound from BFF)
##############################################################################
resource "azurerm_private_endpoint" "middleware" {
  name                = "pe-middleware-${var.project}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-middleware-${var.project}-${var.environment}"
    private_connection_resource_id = azurerm_linux_web_app.middleware.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "dns-group-middleware"
    private_dns_zone_ids = [var.private_dns_zone_app_services_id]
  }
}
