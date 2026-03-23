# =============================================================================
# Variables — All configurable parameters for the infrastructure
# =============================================================================

# -----------------------------------------------------------------------------
# Core
# -----------------------------------------------------------------------------

variable "project" {
  description = "Project name used in resource naming"
  type        = string
  default     = "webapp"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,10}$", var.project))
    error_message = "Project must be 2-11 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "japaneast"
}

variable "secondary_location" {
  description = "Secondary Azure region for geo-replication (DR)"
  type        = string
  default     = "japanwest"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# App Service
# -----------------------------------------------------------------------------

variable "app_sku_name" {
  description = "App Service Plan SKU (B1 for dev, P1v3 for prod)"
  type        = string
  default     = "B1"
}

variable "app_docker_image" {
  description = "Initial Docker image (replaced after first ACR push)"
  type        = string
  default     = "mcr.microsoft.com/appsvc/staticsite:latest"
}

variable "enable_staging_slot" {
  description = "Enable staging deployment slot (requires Standard+ SKU)"
  type        = bool
  default     = false
}

variable "app_min_instance_count" {
  description = "Minimum instance count for auto-scaling"
  type        = number
  default     = 1
}

variable "app_max_instance_count" {
  description = "Maximum instance count for auto-scaling"
  type        = number
  default     = 3
}

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

variable "postgres_sku_name" {
  description = "PostgreSQL Flexible Server SKU"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage size in MB"
  type        = number
  default     = 32768
}

variable "postgres_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "postgres_admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "pgadmin"
}

variable "postgres_ha_enabled" {
  description = "Enable zone-redundant HA for PostgreSQL (prod recommended)"
  type        = bool
  default     = false
}

variable "postgres_backup_retention_days" {
  description = "Backup retention days (7-35). Production: 35 for compliance."
  type        = number
  default     = 7

  validation {
    condition     = var.postgres_backup_retention_days >= 7 && var.postgres_backup_retention_days <= 35
    error_message = "Backup retention must be between 7 and 35 days."
  }
}

# -----------------------------------------------------------------------------
# Redis Cache
# -----------------------------------------------------------------------------

variable "enable_redis" {
  description = "Enable Azure Cache for Redis"
  type        = bool
  default     = false
}

variable "redis_sku_name" {
  description = "Redis SKU: Basic, Standard, Premium"
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.redis_sku_name)
    error_message = "Redis SKU must be Basic, Standard, or Premium."
  }
}

variable "redis_capacity" {
  description = "Redis cache size (0-6 for Basic/Standard, 1-5 for Premium)"
  type        = number
  default     = 0
}

# -----------------------------------------------------------------------------
# Front Door & WAF
# -----------------------------------------------------------------------------

variable "enable_frontdoor" {
  description = "Enable Azure Front Door with WAF"
  type        = bool
  default     = false
}

variable "waf_mode" {
  description = "WAF policy mode: Prevention or Detection"
  type        = string
  default     = "Detection"

  validation {
    condition     = contains(["Prevention", "Detection"], var.waf_mode)
    error_message = "WAF mode must be Prevention or Detection."
  }
}

variable "custom_domain" {
  description = "Custom domain for Front Door (e.g., app.example.com). Empty = skip."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Monitoring & Alerts
# -----------------------------------------------------------------------------

variable "alert_email_recipients" {
  description = "Email addresses for alert notifications"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "Log Analytics workspace retention in days"
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# Cost Management
# -----------------------------------------------------------------------------

variable "enable_budget" {
  description = "Enable Azure budget alerts"
  type        = bool
  default     = false
}

variable "budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 100
}

# -----------------------------------------------------------------------------
# CI/CD (GitHub Actions)
# -----------------------------------------------------------------------------

variable "enable_github_oidc" {
  description = "Create managed identity + federated credential for GitHub Actions"
  type        = bool
  default     = false
}

variable "github_repo" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Disaster Recovery
# -----------------------------------------------------------------------------

variable "enable_geo_replication" {
  description = "Enable ACR geo-replication (requires Premium SKU)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# AZ-104 Study Resources (default: disabled to avoid costs)
# -----------------------------------------------------------------------------

variable "enable_storage" {
  description = "[AZ-104] Enable Azure Storage Account resources"
  type        = bool
  default     = false
}

variable "enable_vm" {
  description = "[AZ-104] Enable Virtual Machine resources"
  type        = bool
  default     = false
}

variable "vm_admin_username" {
  description = "[AZ-104] Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "vm_size" {
  description = "[AZ-104] VM size (Standard_B2s for dev)"
  type        = string
  default     = "Standard_B2s"
}

variable "enable_load_balancer" {
  description = "[AZ-104] Enable Load Balancer resources"
  type        = bool
  default     = false
}

variable "enable_governance" {
  description = "[AZ-104] Enable governance resources (Policy, Locks)"
  type        = bool
  default     = false
}

# =============================================================================
# Locals — Computed values used across the configuration
# =============================================================================

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  # Environment-aware defaults
  is_production = var.environment == "prod"

  # ACR SKU: Premium required for geo-replication & private endpoints
  acr_sku = var.enable_geo_replication || local.is_production ? "Premium" : "Basic"

  # Redis family based on SKU
  redis_family = var.redis_sku_name == "Premium" ? "P" : "C"
}
