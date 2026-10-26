# ---------------------------------------------------------------- wiring from infra/azure

variable "databricks_account_id" {
  description = "Databricks account ID (found in the account console). Placeholder in examples."
  type        = string
}

variable "workspace_url" {
  description = "Workspace URL, output workspace_url of the azure stack."
  type        = string
}

variable "workspace_id" {
  description = "Numeric workspace ID, output workspace_id of the azure stack."
  type        = number
}

variable "metastore_id" {
  description = "ID of the regional Unity Catalog metastore the workspace is attached to."
  type        = string
}

variable "assign_metastore" {
  description = "Create the metastore assignment. Set to false when the region auto-assigns the metastore."
  type        = bool
  default     = true
}

variable "access_connector_id" {
  description = "Resource ID of the access connector, output access_connector_id of the azure stack."
  type        = string
}

variable "storage_account_name" {
  description = "ADLS Gen2 account name, output storage_account_name of the azure stack."
  type        = string
}

# ---------------------------------------------------------------- catalog layout

variable "catalog_prefix" {
  description = "Prefix of the per-environment catalogs (lakehouse_dev, lakehouse_test, lakehouse_prod)."
  type        = string
  default     = "lakehouse"
}

variable "environments" {
  description = "Environments that get their own catalog, in promotion order."
  type        = list(string)
  default     = ["dev", "test", "prod"]

  validation {
    condition     = alltrue([for env in var.environments : contains(["dev", "test", "prod"], env)])
    error_message = "environments may only contain dev, test and prod."
  }
}

variable "medallion_layers" {
  description = "Schemas created in every catalog."
  type        = list(string)
  default     = ["bronze", "silver", "gold"]
}

variable "pipeline_service_principal" {
  description = "Application ID of the service principal that runs test and prod pipelines. Null skips its grants."
  type        = string
  default     = null
}

# ---------------------------------------------------------------- compute and cost

variable "cost_center" {
  description = "Cost center forced as a tag on every cluster and warehouse."
  type        = string
  default     = "cc-0000"
}

variable "job_node_types" {
  description = "Node types allowed on job compute. The first one is the default."
  type        = list(string)
  default     = ["Standard_D4ds_v5", "Standard_D8ds_v5", "Standard_E8ds_v5"]
}

variable "job_max_workers" {
  description = "Upper bound of autoscaling workers on job compute."
  type        = number
  default     = 8
}

variable "interactive_node_types" {
  description = "Node types allowed on small interactive compute."
  type        = list(string)
  default     = ["Standard_D4ds_v5"]
}

variable "interactive_max_workers" {
  description = "Upper bound of workers on small interactive compute."
  type        = number
  default     = 2
}

variable "interactive_max_autotermination_minutes" {
  description = "Longest idle time allowed before an interactive cluster stops."
  type        = number
  default     = 60

  validation {
    condition     = var.interactive_max_autotermination_minutes >= 10 && var.interactive_max_autotermination_minutes <= 120
    error_message = "interactive_max_autotermination_minutes must be between 10 and 120."
  }
}

variable "sql_warehouse_serverless" {
  description = "Run the SQL warehouse on serverless compute. Requires serverless to be enabled on the account."
  type        = bool
  default     = true
}

variable "sql_warehouse_size" {
  description = "T-shirt size of the SQL warehouse."
  type        = string
  default     = "2X-Small"
}

variable "sql_warehouse_max_clusters" {
  description = "Maximum number of clusters the warehouse scales out to."
  type        = number
  default     = 2
}
