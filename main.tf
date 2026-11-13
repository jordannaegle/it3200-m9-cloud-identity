resource "azurerm_resource_group" "lab" {
  name     = "rg-uvu-it3200-${var.student_name}"
  location = var.location
}

resource "azurerm_storage_account" "lab" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
}

resource "azurerm_storage_container" "reports" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.lab.id
  container_access_type = "private"
}