output "resource_group_name" {
  description = "Resource group that holds the platform."
  value       = azurerm_resource_group.this.name
}

output "workspace_id" {
  description = "Numeric Databricks workspace ID, input of the unity-catalog stack."
  value       = azurerm_databricks_workspace.this.workspace_id
}

output "workspace_url" {
  description = "Workspace URL, input of the unity-catalog stack and of the asset bundle."
  value       = "https://${azurerm_databricks_workspace.this.workspace_url}"
}

output "workspace_resource_id" {
  description = "Azure resource ID of the Databricks workspace."
  value       = azurerm_databricks_workspace.this.id
}

output "access_connector_id" {
  description = "Resource ID of the access connector used by the Unity Catalog storage credential."
  value       = azurerm_databricks_access_connector.unity_catalog.id
}

output "storage_account_name" {
  description = "ADLS Gen2 account backing Unity Catalog and the landing zone."
  value       = azurerm_storage_account.lake.name
}

output "unity_catalog_root_url" {
  description = "abfss URL of the Unity Catalog managed storage container."
  value       = "abfss://${azurerm_storage_container.unity_catalog.name}@${azurerm_storage_account.lake.name}.dfs.core.windows.net/"
}

output "landing_url" {
  description = "abfss URL of the landing container read by Auto Loader."
  value       = "abfss://${azurerm_storage_container.landing.name}@${azurerm_storage_account.lake.name}.dfs.core.windows.net/"
}

output "key_vault_uri" {
  description = "URI of the platform Key Vault."
  value       = azurerm_key_vault.this.vault_uri
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace that receives diagnostics."
  value       = azurerm_log_analytics_workspace.this.id
}
