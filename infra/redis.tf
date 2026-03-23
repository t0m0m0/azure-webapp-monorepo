# =============================================================================
# Azure Cache for Redis
# =============================================================================
# Use cases:
#   - Session cache (stateless app instances can share sessions)
#   - Application cache (reduce database load)
#   - Rate limiting backend
#   - Pub/Sub messaging
#
# SKU guide:
#   Basic    (~$16/mo, C0): Dev/test, no SLA, no replication
#   Standard (~$50/mo, C1): Production, SLA, primary+replica
#   Premium  (~$225/mo, P1): VNet injection, clustering, geo-replication
# =============================================================================

resource "azurerm_redis_cache" "main" {
  count               = var.enable_redis ? 1 : 0
  name                = "${local.name_prefix}-redis"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = var.redis_capacity
  family              = local.redis_family
  sku_name            = var.redis_sku_name
  tags                = local.common_tags

  # TLS only — no unencrypted connections
  minimum_tls_version  = "1.2"
  non_ssl_port_enabled = false

  redis_configuration {
    # RDB persistence (Standard and Premium only)
    # Saves snapshots for data durability
  }
}

# -----------------------------------------------------------------------------
# Private Endpoint — Redis
# -----------------------------------------------------------------------------

resource "azurerm_private_endpoint" "redis" {
  count               = var.enable_redis ? 1 : 0
  name                = "${local.name_prefix}-redis-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${local.name_prefix}-redis-psc"
    private_connection_resource_id = azurerm_redis_cache.main[0].id
    is_manual_connection           = false
    subresource_names              = ["redisCache"]
  }

  private_dns_zone_group {
    name                 = "redis-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis[0].id]
  }
}

# -----------------------------------------------------------------------------
# Diagnostic Settings — Redis -> Log Analytics
# -----------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "redis" {
  count                      = var.enable_redis ? 1 : 0
  name                       = "${local.name_prefix}-redis-diag"
  target_resource_id         = azurerm_redis_cache.main[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
