output "catalogs" {
  description = "Catalog name per environment."
  value       = { for env, catalog in databricks_catalog.env : env => catalog.name }
}

output "schemas" {
  description = "Fully qualified schema names, keyed by environment and layer."
  value       = { for key, schema in databricks_schema.layer : key => schema.id }
}

output "job_compute_policy_id" {
  description = "Cluster policy ID to pass to the asset bundle (variable job_policy_id)."
  value       = databricks_cluster_policy.job_compute.id
}

output "interactive_small_policy_id" {
  description = "Cluster policy ID for small interactive clusters."
  value       = databricks_cluster_policy.interactive_small.id
}

output "sql_warehouse_id" {
  description = "ID of the analytics SQL warehouse."
  value       = databricks_sql_endpoint.analytics.id
}

output "landing_url" {
  description = "Landing external location URL, input of the asset bundle (variable landing_path)."
  value       = databricks_external_location.landing.url
}
