resource "azurerm_service_plan" "main" {
  name                = "${local.name_prefix}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_sku_name
  tags                = local.common_tags
}

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
  }
}
