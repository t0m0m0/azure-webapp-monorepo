# =============================================================================
# Disaster Recovery (DR) — Backup & Recovery Vault
# =============================================================================
# DR Strategy for this template:
#
# Component          | RPO        | RTO         | Mechanism
# -------------------|------------|-------------|---------------------------
# App Service        | 0 (stateless) | ~5 min   | Redeploy from ACR
# PostgreSQL         | 5 min      | ~30 min     | Point-in-time restore
# PostgreSQL (HA)    | 0          | ~30 sec     | Zone-redundant failover
# Key Vault          | 0          | Instant     | Soft delete + purge protection
# ACR Images         | 0          | ~5 min      | Geo-replication (Premium)
# Redis              | Varies     | ~5 min      | Rebuild (cache is ephemeral)
#
# RPO = Recovery Point Objective: How much data can you afford to lose?
# RTO = Recovery Time Objective: How quickly must the service be restored?
#
# For mission-critical apps (RPO=0, RTO<1min), consider:
#   - Active-Active multi-region with Azure Front Door traffic routing
#   - PostgreSQL read replicas in secondary region with promotion
#   - Azure Site Recovery for full VM-level replication
# =============================================================================

# -----------------------------------------------------------------------------
# Recovery Services Vault
# -----------------------------------------------------------------------------
# Provides centralized backup management and monitoring.
# Currently used as a placeholder for future backup policies.
# Azure Site Recovery (ASR) for full region failover can be added here.
# -----------------------------------------------------------------------------

resource "azurerm_recovery_services_vault" "main" {
  count               = local.is_production ? 1 : 0
  name                = "${local.name_prefix}-rsv"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  tags                = local.common_tags

  soft_delete_enabled = true

  # Cross-region restore allows restoring backups in the paired region
  cross_region_restore_enabled = true
}

# -----------------------------------------------------------------------------
# DR Runbook (as comments — implement as actual automation if needed)
# -----------------------------------------------------------------------------
#
# Region Failure Runbook:
# 1. Confirm outage via Azure Status page + monitoring alerts
# 2. DNS failover: Update Front Door origin to secondary region App Service
# 3. Database: Promote read replica in secondary region (if configured)
#    - az postgres flexible-server replica promote \
#        --resource-group <rg> --name <replica-name>
# 4. ACR: Images already replicated (geo-replication)
# 5. Redis: Rebuild cache (ephemeral data) or use geo-replicated Premium
# 6. Key Vault: Secrets are region-paired automatically by Azure
# 7. Verify health endpoints in secondary region
# 8. Post-incident: Document timeline, update runbook
#
# Testing:
# - Quarterly DR drill: simulate region failure, measure actual RTO
# - Document results and improve
# =============================================================================
