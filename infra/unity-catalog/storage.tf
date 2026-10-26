resource "databricks_storage_credential" "lake" {
  provider = databricks.workspace

  name    = "${var.catalog_prefix}-access-connector"
  comment = "Managed identity of the Databricks access connector. No keys, no secrets."
  owner   = databricks_group.this["platform_admins"].display_name

  azure_managed_identity {
    access_connector_id = var.access_connector_id
  }

  depends_on = [
    databricks_metastore_assignment.this,
    databricks_mws_permission_assignment.groups,
  ]
}

# One external location per environment, used as the managed storage root of its catalog.
resource "databricks_external_location" "catalog_root" {
  for_each = local.catalogs

  provider        = databricks.workspace
  name            = "${each.value}-root"
  url             = "abfss://unity-catalog@${var.storage_account_name}.dfs.core.windows.net/${each.key}"
  credential_name = databricks_storage_credential.lake.name
  owner           = databricks_group.this["platform_admins"].display_name
  comment         = "Managed storage root of catalog ${each.value}."
}

# Landing zone read by Auto Loader. Files land here; tables never do.
resource "databricks_external_location" "landing" {
  provider        = databricks.workspace
  name            = "${var.catalog_prefix}-landing"
  url             = "abfss://landing@${var.storage_account_name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.lake.name
  owner           = databricks_group.this["platform_admins"].display_name
  comment         = "Raw files dropped by producers, read by ingestion pipelines."
}

resource "databricks_grants" "storage_credential" {
  provider           = databricks.workspace
  storage_credential = databricks_storage_credential.lake.id

  grant {
    principal  = databricks_group.this["platform_admins"].display_name
    privileges = ["CREATE_EXTERNAL_LOCATION"]
  }
}

resource "databricks_grants" "landing" {
  provider          = databricks.workspace
  external_location = databricks_external_location.landing.id

  grant {
    principal  = databricks_group.this["data_engineers"].display_name
    privileges = ["READ_FILES", "BROWSE"]
  }

  dynamic "grant" {
    for_each = var.pipeline_service_principal == null ? [] : [var.pipeline_service_principal]

    content {
      principal  = grant.value
      privileges = ["READ_FILES"]
    }
  }
}
