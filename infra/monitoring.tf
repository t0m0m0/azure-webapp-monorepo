# =============================================================================
# Monitoring, Alerting & Observability
# =============================================================================
# Components:
#   - Log Analytics Workspace (central log store)
#   - Application Insights (APM: traces, metrics, dependency tracking)
#   - Action Group (notification targets: email, webhook)
#   - Alert Rules (CPU, response time, 5xx errors, DB failures)
#   - Availability Test (synthetic ping)
# =============================================================================

# -----------------------------------------------------------------------------
# Log Analytics Workspace
# -----------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.common_tags
}

# -----------------------------------------------------------------------------
# Application Insights
# -----------------------------------------------------------------------------

resource "azurerm_application_insights" "main" {
  name                = "${local.name_prefix}-ai"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.main.id
  tags                = local.common_tags
}

# -----------------------------------------------------------------------------
# Action Group — Who gets notified
# -----------------------------------------------------------------------------

resource "azurerm_monitor_action_group" "main" {
  count               = length(var.alert_email_recipients) > 0 ? 1 : 0
  name                = "${local.name_prefix}-alerts-ag"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "alerts"
  tags                = local.common_tags

  dynamic "email_receiver" {
    for_each = var.alert_email_recipients
    content {
      name          = "email-${email_receiver.key}"
      email_address = email_receiver.value
    }
  }
}

# -----------------------------------------------------------------------------
# Alert: High CPU (> 80% for 5 minutes)
# -----------------------------------------------------------------------------
# Why 80%? Leaves headroom for traffic spikes before auto-scaling kicks in.
# At 100%, users experience latency; we want to know before that.
# -----------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "high_cpu" {
  count               = length(var.alert_email_recipients) > 0 ? 1 : 0
  name                = "${local.name_prefix}-high-cpu"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_service_plan.main.id]
  description         = "CPU usage exceeds 80% for 5 minutes"
  severity            = 2 # Warning
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = local.common_tags

  criteria {
    metric_namespace = "Microsoft.Web/serverfarms"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }
}

# -----------------------------------------------------------------------------
# Alert: Slow Response Time (> 3 seconds average)
# -----------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "slow_response" {
  count               = length(var.alert_email_recipients) > 0 ? 1 : 0
  name                = "${local.name_prefix}-slow-response"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_web_app.main.id]
  description         = "Average response time exceeds 3 seconds"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = local.common_tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HttpResponseTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 3
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }
}

# -----------------------------------------------------------------------------
# Alert: High 5xx Error Rate (> 10 in 5 minutes)
# -----------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "http_5xx" {
  count               = length(var.alert_email_recipients) > 0 ? 1 : 0
  name                = "${local.name_prefix}-5xx-errors"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_web_app.main.id]
  description         = "More than 10 HTTP 5xx errors in 5 minutes"
  severity            = 1 # Critical
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = local.common_tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }
}

# -----------------------------------------------------------------------------
# Alert: Database Connection Failures
# -----------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "db_connection_failed" {
  count               = length(var.alert_email_recipients) > 0 ? 1 : 0
  name                = "${local.name_prefix}-db-conn-fail"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_postgresql_flexible_server.main.id]
  description         = "Database connection failures detected"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = local.common_tags

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "connections_failed"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }
}

# -----------------------------------------------------------------------------
# Alert: Database High CPU
# -----------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "db_high_cpu" {
  count               = length(var.alert_email_recipients) > 0 ? 1 : 0
  name                = "${local.name_prefix}-db-high-cpu"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_postgresql_flexible_server.main.id]
  description         = "Database CPU exceeds 80%"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = local.common_tags

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }
}

# -----------------------------------------------------------------------------
# Availability Test (Synthetic Ping)
# -----------------------------------------------------------------------------
# Probes the /health endpoint every 5 minutes from multiple Azure regions.
# Alerts if the endpoint is unreachable for 2 consecutive failures.
# -----------------------------------------------------------------------------

resource "azurerm_application_insights_standard_web_test" "health" {
  count                   = length(var.alert_email_recipients) > 0 ? 1 : 0
  name                    = "${local.name_prefix}-health-check"
  resource_group_name     = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  application_insights_id = azurerm_application_insights.main.id
  geo_locations           = ["us-tx-sn1-azr", "us-il-ch1-azr", "apac-jp-kaw-edge"]
  frequency               = 300 # 5 minutes
  timeout                 = 30
  enabled                 = true
  tags                    = local.common_tags

  request {
    url = "https://${azurerm_linux_web_app.main.default_hostname}/health"
  }
}
