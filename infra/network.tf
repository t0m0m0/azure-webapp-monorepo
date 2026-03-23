# =============================================================================
# Network Infrastructure
# =============================================================================
# Design: Hub-less spoke with 4 subnets
#   - app:               App Service VNet integration (delegated)
#   - db:                PostgreSQL Flexible Server (delegated)
#   - private-endpoints: Private Endpoints for ACR, Key Vault, Redis
#   - management:        Future use (bastion, jump boxes)
#
# DDoS Protection Note:
#   Azure DDoS Protection Plan costs ~$2,944/month. It's typically enabled
#   at the subscription level by a platform team, not per-project.
#   Basic DDoS protection is included free with every public IP.
# =============================================================================

# -----------------------------------------------------------------------------
# Virtual Network
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network" "main" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------

resource "azurerm_subnet" "app" {
  name                 = "app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault"]

  delegation {
    name = "app-delegation"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "db" {
  name                 = "db"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "db-delegation"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_subnet" "management" {
  name                 = "management"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.4.0/24"]
}

# -----------------------------------------------------------------------------
# NSG — App Subnet
# -----------------------------------------------------------------------------
# When Front Door is enabled, we restrict inbound to the AzureFrontDoor.Backend
# service tag only. This ensures traffic cannot bypass WAF.
# -----------------------------------------------------------------------------

resource "azurerm_network_security_group" "app" {
  name                = "${local.name_prefix}-app-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Allow HTTPS from Front Door (or VNet if Front Door is disabled)
  security_rule {
    name                       = "Allow-HTTPS-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.enable_frontdoor ? "AzureFrontDoor.Backend" : "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-8080-Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = var.enable_frontdoor ? "AzureFrontDoor.Backend" : "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Deny all other inbound
  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-All-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# -----------------------------------------------------------------------------
# NSG — Private Endpoints Subnet
# -----------------------------------------------------------------------------

resource "azurerm_network_security_group" "pe" {
  name                = "${local.name_prefix}-pe-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Only allow traffic from within the VNet
  security_rule {
    name                       = "Allow-VNet-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "pe" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.pe.id
}

# -----------------------------------------------------------------------------
# Private DNS Zones
# -----------------------------------------------------------------------------

# PostgreSQL
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${local.name_prefix}-pg-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.common_tags
}

# ACR
resource "azurerm_private_dns_zone" "acr" {
  count               = local.acr_sku == "Premium" ? 1 : 0
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  count                 = local.acr_sku == "Premium" ? 1 : 0
  name                  = "${local.name_prefix}-acr-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.common_tags
}

# Key Vault
resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "${local.name_prefix}-kv-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.common_tags
}

# Redis
resource "azurerm_private_dns_zone" "redis" {
  count               = var.enable_redis ? 1 : 0
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  count                 = var.enable_redis ? 1 : 0
  name                  = "${local.name_prefix}-redis-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.redis[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.common_tags
}

# -----------------------------------------------------------------------------
# NSG Flow Logs (requires Network Watcher & Storage Account)
# -----------------------------------------------------------------------------
# NSG flow logs are critical for security auditing and troubleshooting.
# They require a storage account for log storage. Uncomment when ready.
#
# resource "azurerm_storage_account" "nsg_flow_logs" {
#   name                     = replace("${local.name_prefix}flowlogs", "-", "")
#   resource_group_name      = azurerm_resource_group.main.name
#   location                 = azurerm_resource_group.main.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
#   tags                     = local.common_tags
# }
#
# resource "azurerm_network_watcher_flow_log" "app_nsg" {
#   name                 = "${local.name_prefix}-app-nsg-flowlog"
#   network_watcher_name = "NetworkWatcher_${var.location}"
#   resource_group_name  = "NetworkWatcherRG"  # Azure auto-creates this RG
#   network_security_group_id = azurerm_network_security_group.app.id
#   storage_account_id   = azurerm_storage_account.nsg_flow_logs.id
#   enabled              = true
#   version              = 2
#
#   retention_policy {
#     enabled = true
#     days    = 30
#   }
#
#   traffic_analytics {
#     enabled               = true
#     workspace_id          = azurerm_log_analytics_workspace.main.workspace_id
#     workspace_region      = azurerm_log_analytics_workspace.main.location
#     workspace_resource_id = azurerm_log_analytics_workspace.main.id
#     interval_in_minutes   = 10
#   }
# }
