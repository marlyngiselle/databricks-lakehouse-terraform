# databricks_grants is authoritative: anything granted by hand on these
# securables is removed on the next apply. That is the point.
resource "databricks_grants" "catalog" {
  for_each = local.catalog_grants

  provider = databricks.workspace
  catalog  = databricks_catalog.env[each.key].name

  dynamic "grant" {
    for_each = each.value

    content {
      principal  = grant.key
      privileges = grant.value
    }
  }

  depends_on = [databricks_mws_permission_assignment.groups]
}

# Analysts read curated data only: gold schemas of test and prod.
resource "databricks_grants" "gold_schema" {
  for_each = local.gold_schemas

  provider = databricks.workspace
  schema   = databricks_schema.layer[each.key].id

  grant {
    principal  = databricks_group.this["data_analysts"].display_name
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}
