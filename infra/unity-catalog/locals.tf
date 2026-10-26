locals {
  # Account groups and the workspace permission each one receives.
  groups = {
    platform_admins = "ADMIN"
    data_engineers  = "USER"
    data_analysts   = "USER"
  }

  catalogs = { for env in var.environments : env => "${var.catalog_prefix}_${env}" }

  schemas = {
    for pair in setproduct(var.environments, var.medallion_layers) :
    "${pair[0]}_${pair[1]}" => { env = pair[0], layer = pair[1] }
  }

  read_privileges = ["USE_CATALOG", "USE_SCHEMA", "BROWSE", "SELECT"]

  write_privileges = concat(local.read_privileges, [
    "MODIFY",
    "REFRESH",
    "CREATE_TABLE",
    "CREATE_MATERIALIZED_VIEW",
    "CREATE_FUNCTION",
    "CREATE_VOLUME",
    "READ_VOLUME",
    "WRITE_VOLUME",
  ])

  # Catalog-level grant matrix. Privileges inherit down to every schema and table.
  # Engineers build in dev and only read above it; the pipeline identity writes
  # in test and prod; analysts are granted gold only, at schema level below.
  catalog_grants = {
    for env in var.environments : env => merge(
      { data_engineers = env == "dev" ? local.write_privileges : local.read_privileges },
      env == "dev" || var.pipeline_service_principal == null ? {} : {
        (var.pipeline_service_principal) = local.write_privileges
      },
      env == "dev" ? {} : { data_analysts = ["USE_CATALOG", "BROWSE"] },
    )
  }

  gold_schemas = {
    for key, schema in local.schemas : key => schema
    if schema.layer == "gold" && schema.env != "dev"
  }

  standard_tags = {
    CostCenter = var.cost_center
    ManagedBy  = "terraform"
    Platform   = var.catalog_prefix
  }
}
