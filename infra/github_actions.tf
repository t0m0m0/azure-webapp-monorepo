# =============================================================================
# GitHub Actions OIDC Identity (Passwordless CI/CD)
# =============================================================================
# Why OIDC instead of Service Principal secrets?
#   - No secrets to rotate or leak
#   - GitHub token is short-lived (valid for ~1 hour per job)
#   - Federated credential: GitHub proves identity to Azure via JWT
#   - Industry best practice since 2022
#
# Flow:
#   GitHub Actions -> Request OIDC token from GitHub
#   GitHub Actions -> Present token to Azure AD
#   Azure AD -> Validate token issuer + subject claim
#   Azure AD -> Issue Azure access token
#   GitHub Actions -> Use Azure token to deploy
# =============================================================================

# -----------------------------------------------------------------------------
# User-Assigned Managed Identity for GitHub Actions
# -----------------------------------------------------------------------------

resource "azurerm_user_assigned_identity" "github_actions" {
  count               = var.enable_github_oidc ? 1 : 0
  name                = "${local.name_prefix}-github-id"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# -----------------------------------------------------------------------------
# Federated Credential — Trust GitHub Actions OIDC tokens
# -----------------------------------------------------------------------------
# Subject claim format: repo:<owner>/<repo>:ref:refs/heads/<branch>
# This ensures only the specified repo+branch can assume this identity.
# -----------------------------------------------------------------------------

resource "azurerm_federated_identity_credential" "github_actions_main" {
  count               = var.enable_github_oidc && var.github_repo != "" ? 1 : 0
  name                = "github-actions-main"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.github_actions[0].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_repo}:ref:refs/heads/main"
}

# Also trust pull request events (for plan/preview)
resource "azurerm_federated_identity_credential" "github_actions_pr" {
  count               = var.enable_github_oidc && var.github_repo != "" ? 1 : 0
  name                = "github-actions-pr"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.github_actions[0].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:${var.github_repo}:environment:production"
}

# -----------------------------------------------------------------------------
# Role Assignments — What can GitHub Actions do?
# -----------------------------------------------------------------------------

# Contributor on resource group (deploy infrastructure)
resource "azurerm_role_assignment" "github_rg_contributor" {
  count                = var.enable_github_oidc ? 1 : 0
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.github_actions[0].principal_id
}

# AcrPush to container registry
resource "azurerm_role_assignment" "github_acr_push" {
  count                = var.enable_github_oidc ? 1 : 0
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.github_actions[0].principal_id
}

# Website Contributor for slot swap
resource "azurerm_role_assignment" "github_app_contributor" {
  count                = var.enable_github_oidc ? 1 : 0
  scope                = azurerm_linux_web_app.main.id
  role_definition_name = "Website Contributor"
  principal_id         = azurerm_user_assigned_identity.github_actions[0].principal_id
}
