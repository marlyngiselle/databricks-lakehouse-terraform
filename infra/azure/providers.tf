provider "azurerm" {
  # Containers and blobs are managed with Entra ID, so shared keys stay disabled.
  storage_use_azuread = true

  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
