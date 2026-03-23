# =============================================================================
# Key Vault — Secrets, Keys, and Certificates
# =============================================================================
# Production enhancements:
#   - Soft delete with 90-day retention (accidental deletion protection)
#   - Private endpoint (no public access to secrets)
#   - Diagnostic settings for audit logging
#   - RBAC authorization (modern approach, replaces access policies)
# =============================================================================

data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# Key Vault
# -----------------------------------------------------------------------------

resource "azurerm_key_vault" "main" {
  name                       = "${local.name_prefix}-kv"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
  tags                       = local.common_tags

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.app.id]
  }
}

# -----------------------------------------------------------------------------
# RBAC — App Service -> Key Vault
# -----------------------------------------------------------------------------

resource "azurerm_role_assignment" "app_keyvault_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

# Allow current Terraform deployer to manage secrets
resource "azurerm_role_assignment" "deployer_keyvault_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# -----------------------------------------------------------------------------
# Secrets
# -----------------------------------------------------------------------------

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.deployer_keyvault_admin]
}

# -----------------------------------------------------------------------------
# Private Endpoint — Key Vault
# -----------------------------------------------------------------------------

resource "azurerm_private_endpoint" "keyvault" {
  name                = "${local.name_prefix}-kv-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "${local.name_prefix}-kv-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "keyvault-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault.id]
  }
}

# -----------------------------------------------------------------------------
# Diagnostic Settings — Key Vault -> Log Analytics
# -----------------------------------------------------------------------------
# Audit logs are critical: who accessed which secret and when
# -----------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "${local.name_prefix}-kv-diag"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
