resource "azurerm_databricks_workspace" "this" {
  name                        = "dbw-${local.name}"
  location                    = azurerm_resource_group.this.location
  resource_group_name         = azurerm_resource_group.this.name
  sku                         = "premium"
  managed_resource_group_name = "rg-${local.name}-dbw-managed"

  # Front-end Private Link closes the public UI and API. Without a back-end
  # endpoint Databricks still needs its NSG rules, so the two settings move together.
  public_network_access_enabled         = !var.enable_private_link_frontend
  network_security_group_rules_required = var.enable_private_link_backend ? "NoAzureDatabricksRules" : "AllRules"

  infrastructure_encryption_enabled = true

  custom_parameters {
    no_public_ip                                         = true
    virtual_network_id                                   = azurerm_virtual_network.this.id
    public_subnet_name                                   = azurerm_subnet.host.name
    private_subnet_name                                  = azurerm_subnet.container.name
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.host.id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.container.id
  }

  tags = local.tags

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = !var.enable_private_link_frontend || var.enable_private_link_backend
      error_message = "enable_private_link_frontend requires enable_private_link_backend: a closed front-end with an open back-end is not a supported topology."
    }
  }
}

# Managed identity that Unity Catalog uses to reach ADLS. No secrets, no keys.
resource "azurerm_databricks_access_connector" "unity_catalog" {
  name                = "dbac-${local.name}-uc"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  identity {
    type = "SystemAssigned"
  }
}
