output "resource_group_name" {
  description = "Resource group containing the lab resources."
  value       = azurerm_resource_group.lab.name
}

output "storage_account_name" {
  description = "Storage account used for blob testing."
  value       = azurerm_storage_account.lab.name
}

output "container_name" {
  description = "Private container used for application reports."
  value       = azurerm_storage_container.reports.name
}

output "container_resource_id" {
  description = "Container resource ID used to scope the RBAC assignment."
  value       = azurerm_storage_container.reports.id
}

output "tenant_id" {
  description = "Microsoft Entra tenant containing the application."
  value       = data.azuread_client_config.current.tenant_id
}

output "application_client_id" {
  description = "Application client ID used when signing in."
  value       = azuread_application.reports.client_id
}

output "service_principal_object_id" {
  description = "Service principal object ID used for RBAC assignments."
  value       = azuread_service_principal.reports.object_id
}

output "client_secret" {
  description = "Temporary credential for service principal testing."
  value       = azuread_application_password.reports.value
  sensitive   = true
}