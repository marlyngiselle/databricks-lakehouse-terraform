resource "databricks_cluster_policy" "job_compute" {
  provider    = databricks.workspace
  name        = "${var.catalog_prefix}-job-compute"
  description = "Ephemeral job clusters: single user, spot with fallback, bounded autoscaling, forced cost tags."

  definition = jsonencode(merge(
    {
      "cluster_type"                  = { type = "fixed", value = "job" }
      "spark_version"                 = { type = "unlimited", defaultValue = "auto:latest-lts" }
      "data_security_mode"            = { type = "fixed", value = "SINGLE_USER", hidden = true }
      "node_type_id"                  = { type = "allowlist", values = var.job_node_types, defaultValue = var.job_node_types[0] }
      "driver_node_type_id"           = { type = "allowlist", values = var.job_node_types, defaultValue = var.job_node_types[0] }
      "autoscale.min_workers"         = { type = "range", minValue = 1, maxValue = 2, defaultValue = 1 }
      "autoscale.max_workers"         = { type = "range", minValue = 1, maxValue = var.job_max_workers, defaultValue = 4 }
      "azure_attributes.availability" = { type = "fixed", value = "SPOT_WITH_FALLBACK_AZURE", hidden = true }
      "runtime_engine"                = { type = "allowlist", values = ["STANDARD", "PHOTON"], defaultValue = "PHOTON" }
      "custom_tags.Workload"          = { type = "fixed", value = "job" }
    },
    { for key, value in local.standard_tags : "custom_tags.${key}" => { type = "fixed", value = value } },
  ))
}

resource "databricks_cluster_policy" "interactive_small" {
  provider              = databricks.workspace
  name                  = "${var.catalog_prefix}-interactive-small"
  description           = "Small shared clusters for exploration: auto-termination enforced, one cluster per user."
  max_clusters_per_user = 1

  definition = jsonencode(merge(
    {
      "cluster_type"            = { type = "fixed", value = "all-purpose" }
      "spark_version"           = { type = "unlimited", defaultValue = "auto:latest-lts" }
      "data_security_mode"      = { type = "fixed", value = "USER_ISOLATION" }
      "node_type_id"            = { type = "allowlist", values = var.interactive_node_types, defaultValue = var.interactive_node_types[0] }
      "driver_node_type_id"     = { type = "allowlist", values = var.interactive_node_types, defaultValue = var.interactive_node_types[0] }
      "num_workers"             = { type = "range", minValue = 0, maxValue = var.interactive_max_workers, defaultValue = 1 }
      "autotermination_minutes" = { type = "range", minValue = 10, maxValue = var.interactive_max_autotermination_minutes, defaultValue = 30 }
      "custom_tags.Workload"    = { type = "fixed", value = "interactive" }
    },
    { for key, value in local.standard_tags : "custom_tags.${key}" => { type = "fixed", value = value } },
  ))
}

resource "databricks_permissions" "job_compute_policy" {
  provider          = databricks.workspace
  cluster_policy_id = databricks_cluster_policy.job_compute.id

  access_control {
    group_name       = databricks_group.this["data_engineers"].display_name
    permission_level = "CAN_USE"
  }

  dynamic "access_control" {
    for_each = var.pipeline_service_principal == null ? [] : [var.pipeline_service_principal]

    content {
      service_principal_name = access_control.value
      permission_level       = "CAN_USE"
    }
  }

  depends_on = [databricks_mws_permission_assignment.groups]
}

resource "databricks_permissions" "interactive_small_policy" {
  provider          = databricks.workspace
  cluster_policy_id = databricks_cluster_policy.interactive_small.id

  access_control {
    group_name       = databricks_group.this["data_engineers"].display_name
    permission_level = "CAN_USE"
  }

  depends_on = [databricks_mws_permission_assignment.groups]
}

resource "databricks_sql_endpoint" "analytics" {
  provider                  = databricks.workspace
  name                      = "${var.catalog_prefix}-analytics"
  cluster_size              = var.sql_warehouse_size
  min_num_clusters          = 1
  max_num_clusters          = var.sql_warehouse_max_clusters
  auto_stop_mins            = var.sql_warehouse_serverless ? 5 : 15
  enable_serverless_compute = var.sql_warehouse_serverless
  warehouse_type            = "PRO"
  spot_instance_policy      = "COST_OPTIMIZED"

  tags {
    dynamic "custom_tags" {
      for_each = merge(local.standard_tags, { Workload = "sql" })

      content {
        key   = custom_tags.key
        value = custom_tags.value
      }
    }
  }
}

resource "databricks_permissions" "analytics_warehouse" {
  provider        = databricks.workspace
  sql_endpoint_id = databricks_sql_endpoint.analytics.id

  access_control {
    group_name       = databricks_group.this["platform_admins"].display_name
    permission_level = "CAN_MANAGE"
  }

  access_control {
    group_name       = databricks_group.this["data_engineers"].display_name
    permission_level = "CAN_USE"
  }

  access_control {
    group_name       = databricks_group.this["data_analysts"].display_name
    permission_level = "CAN_USE"
  }

  depends_on = [databricks_mws_permission_assignment.groups]
}
