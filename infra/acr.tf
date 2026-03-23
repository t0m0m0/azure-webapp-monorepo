# =============================================================================
# Azure Container Registry (ACR)
# =============================================================================
# Production enhancements:
#   - Premium SKU for geo-replication & private endpoints (when enabled)
#   - admin_enabled = false (use Managed Identity for ACR pull)
#   - Retention policy for untagged images (cost control)
#   - Geo-replication for DR
#   - Private endpoint (Premium SKU only)
# =============================================================================

resource "azurerm_container_registry" "main" {
  name                = replace("${local.name_prefix}acr", "-", "")
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = local.acr_sku
  admin_enabled       = false # Use Managed Identity instead
  tags                = local.common_tags

  # Retention policy: auto-delete untagged manifests after 30 days
  # Only available on Premium SKU
  dynamic "retention_policy" {
    for_each = local.acr_sku == "Premium" ? [1] : []
    content {
      days    = 30
      enabled = true
    }
  }

  # Geo-replication: replicate images to secondary region for DR
  dynamic "georeplications" {
    for_each = var.enable_geo_replication ? [1] : []
    content {
      location                = var.secondary_location
      zone_redundancy_enabled = true
      tags                    = local.common_tags
    }
  }
}

# -----------------------------------------------------------------------------
# Private Endpoint — ACR (Premium SKU only)
# -----------------------------------------------------------------------------

resource "azurerm_private_endpoint" "acr" {
  count               = local.acr_sku == "Premium" ? 1 : 0
  name                = "${local.name_prefix}-acr-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${local.name_prefix}-acr-psc"
    private_connection_resource_id = azurerm_container_registry.main.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "acr-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr[0].id]
  }
}

# -----------------------------------------------------------------------------
# Diagnostic Settings — ACR -> Log Analytics
# -----------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "${local.name_prefix}-acr-diag"
  target_resource_id         = azurerm_container_registry.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
