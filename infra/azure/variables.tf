variable "project" {
  description = "Short project name used in every resource name."
  type        = string
  default     = "lakehouse"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,11}$", var.project))
    error_message = "project must be 3 to 12 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment of this platform instance."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of dev, test or prod."
  }
}

variable "location" {
  description = "Azure region for every resource in the stack."
  type        = string
  default     = "westeurope"
}

variable "unique_suffix" {
  description = "Short suffix that makes globally unique names (storage account, Key Vault) unique."
  type        = string
  default     = "a1b2"

  validation {
    condition     = can(regex("^[a-z0-9]{3,6}$", var.unique_suffix))
    error_message = "unique_suffix must be 3 to 6 lowercase alphanumeric characters."
  }
}

variable "tags" {
  description = "Tags applied to every resource, merged with the standard platform tags."
  type        = map(string)
  default     = {}
}

variable "cost_center" {
  description = "Cost center tag value used for chargeback."
  type        = string
  default     = "cc-0000"
}

# ---------------------------------------------------------------- network

variable "vnet_address_space" {
  description = "Address space of the VNet that hosts the Databricks data plane."
  type        = list(string)
  default     = ["10.20.0.0/22"]
}

variable "host_subnet_prefix" {
  description = "CIDR of the host (public) subnet delegated to Databricks. A /26 or larger is required."
  type        = string
  default     = "10.20.0.0/24"
}

variable "container_subnet_prefix" {
  description = "CIDR of the container (private) subnet delegated to Databricks. A /26 or larger is required."
  type        = string
  default     = "10.20.1.0/24"
}

variable "private_endpoint_subnet_prefix" {
  description = "CIDR of the subnet that holds private endpoints (Databricks, storage)."
  type        = string
  default     = "10.20.2.0/27"
}

variable "enable_private_link_backend" {
  description = "Create a back-end private endpoint so clusters reach the control plane over Private Link."
  type        = bool
  default     = false
}

variable "enable_private_link_frontend" {
  description = "Create front-end private endpoints (UI, API, browser authentication) and disable public workspace access. Requires the back-end endpoint."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------- storage and security

variable "storage_network_default_action" {
  description = "Default action of the storage firewall. Keep Deny outside of throwaway sandboxes."
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Allow", "Deny"], var.storage_network_default_action)
    error_message = "storage_network_default_action must be Allow or Deny."
  }
}

variable "allowed_ip_ranges" {
  description = "Public CIDRs (for example a CI runner egress) allowed through the storage and Key Vault firewalls."
  type        = list(string)
  default     = []
}

variable "key_vault_admin_object_ids" {
  description = "Entra ID object IDs granted Key Vault Administrator on the platform Key Vault."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------- monitoring

variable "log_retention_days" {
  description = "Retention of the Log Analytics workspace, in days."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730."
  }
}

variable "databricks_diagnostic_categories" {
  description = "Databricks diagnostic log categories sent to Log Analytics."
  type        = list(string)
  default = [
    "accounts",
    "clusters",
    "jobs",
    "notebook",
    "secrets",
    "sqlPermissions",
    "unityCatalog",
    "workspace",
    "deltaPipelines",
    "databrickssql",
  ]
}
