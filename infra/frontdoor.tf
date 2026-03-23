# =============================================================================
# Azure Front Door + WAF Policy
# =============================================================================
# Front Door provides:
#   - Global load balancing & acceleration (anycast)
#   - WAF with OWASP managed rules (SQL injection, XSS, etc.)
#   - Rate limiting (DDoS mitigation layer)
#   - SSL termination & custom domains
#   - Caching at edge locations
#
# Why Front Door over Application Gateway?
#   - Front Door = global L7 load balancer (edge network, 180+ PoPs)
#   - App Gateway = regional L7 load balancer (inside VNet)
#   - For SaaS/public web apps, Front Door is the modern choice.
#   - App Gateway is for hybrid/on-prem or when you need VNet-level control.
# =============================================================================

# -----------------------------------------------------------------------------
# Front Door Profile
# -----------------------------------------------------------------------------
# Premium_AzureFrontDoor is required for WAF with managed rule sets.
# Standard_AzureFrontDoor only supports custom WAF rules.
# -----------------------------------------------------------------------------

resource "azurerm_cdn_frontdoor_profile" "main" {
  count               = var.enable_frontdoor ? 1 : 0
  name                = "${local.name_prefix}-fd"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Premium_AzureFrontDoor"
  tags                = local.common_tags
}

# -----------------------------------------------------------------------------
# Origin Group (backend pool)
# -----------------------------------------------------------------------------

resource "azurerm_cdn_frontdoor_origin_group" "app" {
  count                    = var.enable_frontdoor ? 1 : 0
  name                     = "app-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main[0].id
  session_affinity_enabled = false

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/health"
    protocol            = "Https"
    interval_in_seconds = 30
    request_type        = "GET"
  }
}

# -----------------------------------------------------------------------------
# Origin (App Service backend)
# -----------------------------------------------------------------------------

resource "azurerm_cdn_frontdoor_origin" "app" {
  count                          = var.enable_frontdoor ? 1 : 0
  name                           = "app-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.app[0].id
  enabled                        = true
  host_name                      = azurerm_linux_web_app.main.default_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_linux_web_app.main.default_hostname
  certificate_name_check_enabled = true
  priority                       = 1
  weight                         = 1000
}

# -----------------------------------------------------------------------------
# Endpoint
# -----------------------------------------------------------------------------

resource "azurerm_cdn_frontdoor_endpoint" "main" {
  count                    = var.enable_frontdoor ? 1 : 0
  name                     = "${local.name_prefix}-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main[0].id
  tags                     = local.common_tags
}

# -----------------------------------------------------------------------------
# Route (connects endpoint -> origin group)
# -----------------------------------------------------------------------------

resource "azurerm_cdn_frontdoor_route" "app" {
  count                         = var.enable_frontdoor ? 1 : 0
  name                          = "app-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main[0].id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.app[0].id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.app[0].id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true

  cdn_frontdoor_origin_path = "/"

  cache {
    query_string_caching_behavior = "IgnoreQueryString"
    compression_enabled           = true
    content_types_to_compress = [
      "text/html",
      "text/css",
      "application/javascript",
      "application/json",
      "image/svg+xml",
    ]
  }

  link_to_default_domain = true
}

# -----------------------------------------------------------------------------
# WAF Policy
# -----------------------------------------------------------------------------
# OWASP managed rules protect against:
#   - SQL Injection, XSS, Path Traversal, Command Injection
#   - Protocol violations, scanner detection, session fixation
#
# Rate limiting: 1000 requests per minute per IP
#   - Protects against layer 7 DDoS and brute force
# -----------------------------------------------------------------------------

resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  count               = var.enable_frontdoor ? 1 : 0
  name                = replace("${local.name_prefix}-waf", "-", "")
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Premium_AzureFrontDoor"
  enabled             = true
  mode                = var.waf_mode
  tags                = local.common_tags

  # OWASP Default Rule Set (DRS) 2.1
  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }

  # Bot Manager Rule Set
  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.1"
    action  = "Block"
  }

  # Rate limiting: 1000 requests / 1 minute per IP
  custom_rule {
    name     = "RateLimitPerIP"
    enabled  = true
    priority = 100
    type     = "RateLimitRule"
    action   = "Block"

    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 1000

    match_condition {
      match_variable = "SocketAddr"
      operator       = "IPMatch"
      match_values   = ["0.0.0.0/0"]
    }
  }
}

# -----------------------------------------------------------------------------
# Security Policy (associates WAF with endpoint)
# -----------------------------------------------------------------------------

resource "azurerm_cdn_frontdoor_security_policy" "main" {
  count                    = var.enable_frontdoor ? 1 : 0
  name                     = "waf-policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main[0].id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.main[0].id

      association {
        patterns_to_match = ["/*"]

        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.main[0].id
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Custom Domain (uncomment and configure when ready)
# -----------------------------------------------------------------------------
# To add a custom domain:
#   1. Create a CNAME record: app.example.com -> <endpoint>.z01.azurefd.net
#   2. Uncomment the resources below
#   3. Azure will auto-provision a managed TLS certificate
#
# resource "azurerm_cdn_frontdoor_custom_domain" "main" {
#   count                    = var.enable_frontdoor && var.custom_domain != "" ? 1 : 0
#   name                     = "custom-domain"
#   cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main[0].id
#   host_name                = var.custom_domain
#
#   tls {
#     certificate_type    = "ManagedCertificate"
#     minimum_tls_version = "TLS12"
#   }
# }

# -----------------------------------------------------------------------------
# Diagnostic Settings — Front Door -> Log Analytics
# -----------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "frontdoor" {
  count                      = var.enable_frontdoor ? 1 : 0
  name                       = "${local.name_prefix}-fd-diag"
  target_resource_id         = azurerm_cdn_frontdoor_profile.main[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "FrontDoorAccessLog"
  }

  enabled_log {
    category = "FrontDoorWebApplicationFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
