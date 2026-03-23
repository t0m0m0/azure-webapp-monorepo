# =============================================================================
# Azure Cost Management — Budget Alerts
# =============================================================================
# Why: Cloud costs can spiral out of control without guardrails.
# Real story: Dev environment left running over a holiday → $10K surprise bill.
#
# Alerts at 50%, 80%, 100% of budget:
#   50% = early warning ("are we on track?")
#   80% = take action (scale down dev environments)
#   100% = investigate immediately
#
# Note: Budgets do NOT stop spending. They only alert.
# For hard limits, use Azure Policy or subscription-level spending caps.
# =============================================================================

data "azurerm_subscription" "current" {}

resource "azurerm_consumption_budget_resource_group" "main" {
  count             = var.enable_budget ? 1 : 0
  name              = "${local.name_prefix}-budget"
  resource_group_id = azurerm_resource_group.main.id

  amount     = var.budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  filter {
    tag {
      name   = "Project"
      values = [var.project]
    }
  }

  # 50% — Heads up
  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"

    contact_emails = var.alert_email_recipients
  }

  # 80% — Take action
  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"

    contact_emails = var.alert_email_recipients
  }

  # 100% — Over budget
  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"

    contact_emails = var.alert_email_recipients
  }

  # 120% forecast — We're projected to exceed
  notification {
    enabled        = true
    threshold      = 120
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Forecasted"

    contact_emails = var.alert_email_recipients
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}
