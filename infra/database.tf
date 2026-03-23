# =============================================================================
# PostgreSQL Flexible Server
# =============================================================================
# Production enhancements:
#   - Zone-redundant HA (optional, for prod)
#   - 35-day backup retention (regulatory compliance)
#   - Maintenance window (Sunday 2 AM JST)
#   - Connection throttling & logging
#   - Read replica (commented out — for analytics workload separation)
# =============================================================================

resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

# -----------------------------------------------------------------------------
# PostgreSQL Flexible Server
# -----------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${local.name_prefix}-pgserver"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  administrator_login    = var.postgres_admin_username
  administrator_password = random_password.db_password.result
  sku_name               = var.postgres_sku_name
  storage_mb             = var.postgres_storage_mb
  version                = var.postgres_version
  delegated_subnet_id    = azurerm_subnet.db.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres.id
  zone                   = "1"
  tags                   = local.common_tags

  # Backup retention: 7 days for dev, 35 for prod (compliance)
  backup_retention_days        = var.postgres_backup_retention_days
  geo_redundant_backup_enabled = local.is_production

  # Zone-redundant HA: standby in a different availability zone
  # Automatic failover with ~30s downtime
  dynamic "high_availability" {
    for_each = var.postgres_ha_enabled ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = "2"
    }
  }

  # Maintenance window: Sunday 2:00 AM JST (17:00 UTC Saturday)
  maintenance_window {
    day_of_week  = 0 # Sunday
    start_hour   = 17
    start_minute = 0
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres,
  ]
}

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = "${var.project}db"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# -----------------------------------------------------------------------------
# Server Configuration — Security & Performance
# -----------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server_configuration" "require_ssl" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

# Connection throttling: protects against brute-force and runaway connections
resource "azurerm_postgresql_flexible_server_configuration" "connection_throttling" {
  name      = "connection_throttle.enable"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

# Log checkpoints for performance monitoring
resource "azurerm_postgresql_flexible_server_configuration" "log_checkpoints" {
  name      = "log_checkpoints"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

# Log connections for security auditing
resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

# Log disconnections for troubleshooting
resource "azurerm_postgresql_flexible_server_configuration" "log_disconnections" {
  name      = "log_disconnections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

# Log long-running queries (> 1 second)
resource "azurerm_postgresql_flexible_server_configuration" "log_min_duration_statement" {
  name      = "log_min_duration_statement"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "1000" # milliseconds
}

# -----------------------------------------------------------------------------
# Diagnostic Settings — PostgreSQL -> Log Analytics
# -----------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "postgres" {
  name                       = "${local.name_prefix}-pg-diag"
  target_resource_id         = azurerm_postgresql_flexible_server.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "PostgreSQLLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# -----------------------------------------------------------------------------
# Read Replica (Commented Out)
# -----------------------------------------------------------------------------
# Use a read replica to offload analytics/reporting queries from the primary.
# This prevents heavy report queries from impacting production user traffic.
#
# Cost: Same SKU as primary (~$50-400/month depending on SKU).
# Replication lag: Typically < 1 second for Azure PostgreSQL.
#
# resource "azurerm_postgresql_flexible_server" "replica" {
#   name                = "${local.name_prefix}-pgserver-replica"
#   resource_group_name = azurerm_resource_group.main.name
#   location            = azurerm_resource_group.main.location
#   create_mode         = "Replica"
#   source_server_id    = azurerm_postgresql_flexible_server.main.id
#   sku_name            = var.postgres_sku_name
#   storage_mb          = var.postgres_storage_mb
#   version             = var.postgres_version
#   zone                = "2"
#   tags                = local.common_tags
# }
