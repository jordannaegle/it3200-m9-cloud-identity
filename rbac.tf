resource "azurerm_role_assignment" "reports_blob_access" {
  scope                = azurerm_storage_container.reports.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.reports.object_id
}