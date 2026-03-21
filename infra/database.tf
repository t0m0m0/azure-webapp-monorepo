resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!@#$%"
}

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

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres,
  ]
}

resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = "${var.project}db"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_configuration" "require_ssl" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}
