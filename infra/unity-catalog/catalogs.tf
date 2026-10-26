resource "databricks_catalog" "env" {
  for_each = local.catalogs

  provider       = databricks.workspace
  name           = each.value
  comment        = "Lakehouse catalog for the ${each.key} environment."
  storage_root   = databricks_external_location.catalog_root[each.key].url
  owner          = databricks_group.this["platform_admins"].display_name
  isolation_mode = "ISOLATED"

  properties = {
    environment = each.key
  }
}

# Isolated catalogs are only visible from the workspaces they are bound to.
resource "databricks_workspace_binding" "env" {
  for_each = local.catalogs

  provider       = databricks.workspace
  securable_name = databricks_catalog.env[each.key].name
  securable_type = "catalog"
  workspace_id   = var.workspace_id
  binding_type   = "BINDING_TYPE_READ_WRITE"
}

resource "databricks_schema" "layer" {
  for_each = local.schemas

  provider     = databricks.workspace
  catalog_name = databricks_catalog.env[each.value.env].name
  name         = each.value.layer
  owner        = databricks_group.this["platform_admins"].display_name
  comment      = "${title(each.value.layer)} layer of the ${each.value.env} lakehouse."

  properties = {
    layer = each.value.layer
  }
}
