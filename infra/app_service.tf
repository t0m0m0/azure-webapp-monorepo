# =============================================================================
# App Service Plan + Linux Web App + Staging Slot + Auto-scaling
# =============================================================================
# Production best practices:
#   - Managed Identity for ACR pull (no admin credentials)
#   - Staging slot for blue/green deployments
#   - Auto-scaling rules (CPU + HTTP requests)
#   - IP restrictions (Front Door only, when enabled)
#   - Minimum TLS 1.2
#   - Diagnostic settings -> Log Analytics
# =============================================================================

# -----------------------------------------------------------------------------
# App Service Plan
# -----------------------------------------------------------------------------

resource "azurerm_service_plan" "main" {
  name                = "${local.name_prefix}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_sku_name
  tags                = local.common_tags
}

# -----------------------------------------------------------------------------
# Linux Web App
# -----------------------------------------------------------------------------

resource "azurerm_linux_web_app" "main" {
  name                      = "${local.name_prefix}-app"
  resource_group_name       = azurerm_resource_group.main.name
  location                  = azurerm_resource_group.main.location
  service_plan_id           = azurerm_service_plan.main.id
  virtual_network_subnet_id = azurerm_subnet.app.id
  https_only                = true
  tags                      = local.common_tags

  site_config {
    always_on                               = true
    container_registry_use_managed_identity = true
    health_check_path                       = "/health"
    minimum_tls_version                     = "1.2"
    ftps_state                              = "Disabled"
    http2_enabled                           = true
    vnet_route_all_enabled                  = true

    application_stack {
      docker_image_name = var.app_docker_image
    }

    # When Front Door is enabled, only allow traffic from Front Door
    dynamic "ip_restriction" {
      for_each = var.enable_frontdoor ? [1] : []
      content {
        service_tag = "AzureFrontDoor.Backend"
        name        = "Allow-FrontDoor"
        priority    = 100
        action      = "Allow"
        headers {
          x_azure_fdid = var.enable_frontdoor ? [azurerm_cdn_frontdoor_profile.main[0].resource_guid] : []
        }
      }
    }
  }

  app_settings = {
    WEBSITES_PORT                         = "8080"
    PORT                                  = "8080"
    DATABASE_URL                          = "postgresql://${var.postgres_admin_username}:${urlencode(random_password.db_password.result)}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${var.project}db?sslmode=require"
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.main.connection_string
    KEY_VAULT_URI                         = azurerm_key_vault.main.vault_uri
    REDIS_URL                             = var.enable_redis ? "rediss://:${azurerm_redis_cache.main[0].primary_access_key}@${azurerm_redis_cache.main[0].hostname}:${azurerm_redis_cache.main[0].ssl_port}" : ""
  }

  identity {
    type = "SystemAssigned"
  }

  logs {
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
    application_logs {
      file_system_level = "Information"
    }
  }

  sticky_settings {
    app_setting_names = ["APPLICATIONINSIGHTS_CONNECTION_STRING"]
  }
}

# -----------------------------------------------------------------------------
# ACR Pull Role Assignment (Managed Identity — no admin password)
# -----------------------------------------------------------------------------

resource "azurerm_role_assignment" "app_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

# -----------------------------------------------------------------------------
# Staging Deployment Slot (Blue/Green)
# -----------------------------------------------------------------------------
# Requires Standard (S1) or Premium (P1v3) SKU.
# Traffic is routed to staging for testing, then swapped to production.
# Swap is instant and zero-downtime.
# -----------------------------------------------------------------------------

resource "azurerm_linux_web_app_slot" "staging" {
  count          = var.enable_staging_slot ? 1 : 0
  name           = "staging"
  app_service_id = azurerm_linux_web_app.main.id
  tags           = local.common_tags

  site_config {
    always_on                               = true
    container_registry_use_managed_identity = true
    health_check_path                       = "/health"
    minimum_tls_version                     = "1.2"
    ftps_state                              = "Disabled"
    http2_enabled                           = true
    vnet_route_all_enabled                  = true

    application_stack {
      docker_image_name = var.app_docker_image
    }
  }

  app_settings = {
    WEBSITES_PORT                         = "8080"
    PORT                                  = "8080"
    DATABASE_URL                          = "postgresql://${var.postgres_admin_username}:${urlencode(random_password.db_password.result)}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${var.project}db?sslmode=require"
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.main.connection_string
    KEY_VAULT_URI                         = azurerm_key_vault.main.vault_uri
    SLOT_NAME                             = "staging"
  }

  identity {
    type = "SystemAssigned"
  }
}

# ACR Pull for staging slot
resource "azurerm_role_assignment" "staging_acr_pull" {
  count                = var.enable_staging_slot ? 1 : 0
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app_slot.staging[0].identity[0].principal_id
}

# Key Vault access for staging slot
resource "azurerm_role_assignment" "staging_keyvault_secrets_user" {
  count                = var.enable_staging_slot ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app_slot.staging[0].identity[0].principal_id
}

# -----------------------------------------------------------------------------
# Auto-scaling (CPU + HTTP request based)
# -----------------------------------------------------------------------------
# Rules:
#   - Scale OUT when avg CPU > 70% for 5 min
#   - Scale IN  when avg CPU < 30% for 5 min
#   - Scale OUT when HTTP requests > 1000/min for 5 min
# -----------------------------------------------------------------------------

resource "azurerm_monitor_autoscale_setting" "app" {
  name                = "${local.name_prefix}-autoscale"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_service_plan.main.id
  tags                = local.common_tags

  profile {
    name = "default"

    capacity {
      default = var.app_min_instance_count
      minimum = var.app_min_instance_count
      maximum = var.app_max_instance_count
    }

    # Scale OUT on high CPU
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    # Scale IN on low CPU
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }

    # Scale OUT on high HTTP requests
    rule {
      metric_trigger {
        metric_name        = "HttpQueueLength"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 100
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = false
      custom_emails                         = var.alert_email_recipients
    }
  }
}

# -----------------------------------------------------------------------------
# Diagnostic Settings — App Service -> Log Analytics
# -----------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "app_service" {
  name                       = "${local.name_prefix}-app-diag"
  target_resource_id         = azurerm_linux_web_app.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  enabled_log {
    category = "AppServiceAppLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
