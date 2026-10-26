locals {
  private_link_enabled = var.enable_private_link_backend || var.enable_private_link_frontend
}

resource "azurerm_private_dns_zone" "databricks" {
  count = local.private_link_enabled ? 1 : 0

  name                = "privatelink.azuredatabricks.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "databricks" {
  count = local.private_link_enabled ? 1 : 0

  name                  = "link-${local.name}-dbw"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.databricks[0].name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = local.tags
}

# Back-end: cluster nodes reach the control plane (SCC relay, REST API) privately.
resource "azurerm_private_endpoint" "databricks_backend" {
  count = var.enable_private_link_backend ? 1 : 0

  name                = "pe-${local.name}-dbw-backend"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-${local.name}-dbw-backend"
    private_connection_resource_id = azurerm_databricks_workspace.this.id
    subresource_names              = ["databricks_ui_api"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "databricks"
    private_dns_zone_ids = [azurerm_private_dns_zone.databricks[0].id]
  }
}

# Front-end: users reach the UI through the corporate network. In a hub and spoke
# design this endpoint lives in a transit VNet; here it shares the endpoint subnet.
resource "azurerm_private_endpoint" "databricks_frontend" {
  count = var.enable_private_link_frontend ? 1 : 0

  name                = "pe-${local.name}-dbw-frontend"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-${local.name}-dbw-frontend"
    private_connection_resource_id = azurerm_databricks_workspace.this.id
    subresource_names              = ["databricks_ui_api"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "databricks"
    private_dns_zone_ids = [azurerm_private_dns_zone.databricks[0].id]
  }

  depends_on = [azurerm_private_endpoint.databricks_backend]
}

# Browser single sign-on callback. One per region and private DNS zone is enough.
resource "azurerm_private_endpoint" "databricks_browser_auth" {
  count = var.enable_private_link_frontend ? 1 : 0

  name                = "pe-${local.name}-dbw-auth"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-${local.name}-dbw-auth"
    private_connection_resource_id = azurerm_databricks_workspace.this.id
    subresource_names              = ["browser_authentication"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "databricks"
    private_dns_zone_ids = [azurerm_private_dns_zone.databricks[0].id]
  }

  depends_on = [azurerm_private_endpoint.databricks_frontend]
}
