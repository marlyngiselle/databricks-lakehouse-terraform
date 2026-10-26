# Account-level groups. In production these are usually provisioned by SCIM from
# Entra ID; import them instead of letting Terraform create duplicates.
resource "databricks_group" "this" {
  for_each = local.groups

  provider     = databricks.account
  display_name = each.key
}

resource "databricks_mws_permission_assignment" "groups" {
  for_each = local.groups

  provider     = databricks.account
  workspace_id = var.workspace_id
  principal_id = databricks_group.this[each.key].id
  permissions  = [each.value]
}

resource "databricks_metastore_assignment" "this" {
  count = var.assign_metastore ? 1 : 0

  provider     = databricks.account
  workspace_id = var.workspace_id
  metastore_id = var.metastore_id
}
