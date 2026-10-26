# Account-level provider: groups, workspace assignment, metastore assignment.
# Authentication comes from the environment (Azure CLI, or ARM_CLIENT_ID and
# ARM_TENANT_ID with OIDC in CI), never from this file.
provider "databricks" {
  alias      = "account"
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
}

# Workspace-level provider: Unity Catalog securables, grants, policies, warehouses.
provider "databricks" {
  alias = "workspace"
  host  = var.workspace_url
}
