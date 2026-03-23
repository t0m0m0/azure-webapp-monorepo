# =============================================================================
# Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Core
# -----------------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

# -----------------------------------------------------------------------------
# App Service
# -----------------------------------------------------------------------------

output "app_service_url" {
  description = "URL of the App Service"
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "app_service_name" {
  description = "Name of the App Service"
  value       = azurerm_linux_web_app.main.name
}

output "staging_slot_url" {
  description = "URL of the staging slot (if enabled)"
  value       = var.enable_staging_slot ? "https://${azurerm_linux_web_app_slot.staging[0].default_hostname}" : "(staging slot disabled)"
}

# -----------------------------------------------------------------------------
# Container Registry
# -----------------------------------------------------------------------------

output "acr_login_server" {
  description = "Login server for the Azure Container Registry"
  value       = azurerm_container_registry.main.login_server
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

output "postgresql_fqdn" {
  description = "FQDN of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

# -----------------------------------------------------------------------------
# Key Vault
# -----------------------------------------------------------------------------

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

# -----------------------------------------------------------------------------
# Monitoring
# -----------------------------------------------------------------------------

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

# -----------------------------------------------------------------------------
# Front Door (conditional)
# -----------------------------------------------------------------------------

output "frontdoor_endpoint_url" {
  description = "Azure Front Door endpoint URL"
  value       = var.enable_frontdoor ? "https://${azurerm_cdn_frontdoor_endpoint.main[0].host_name}" : "(Front Door disabled)"
}

output "frontdoor_id" {
  description = "Front Door profile resource GUID (for IP restriction headers)"
  value       = var.enable_frontdoor ? azurerm_cdn_frontdoor_profile.main[0].resource_guid : ""
}

# -----------------------------------------------------------------------------
# Redis (conditional)
# -----------------------------------------------------------------------------

output "redis_hostname" {
  description = "Redis cache hostname"
  value       = var.enable_redis ? azurerm_redis_cache.main[0].hostname : "(Redis disabled)"
}

output "redis_ssl_port" {
  description = "Redis SSL port"
  value       = var.enable_redis ? azurerm_redis_cache.main[0].ssl_port : 0
}

# -----------------------------------------------------------------------------
# GitHub Actions OIDC (conditional)
# -----------------------------------------------------------------------------

output "github_actions_client_id" {
  description = "Client ID for GitHub Actions OIDC authentication"
  value       = var.enable_github_oidc ? azurerm_user_assigned_identity.github_actions[0].client_id : ""
}

output "github_actions_tenant_id" {
  description = "Tenant ID for GitHub Actions OIDC authentication"
  value       = var.enable_github_oidc ? data.azurerm_client_config.current.tenant_id : ""
}
