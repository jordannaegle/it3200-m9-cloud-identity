data "azuread_client_config" "current" {}

resource "azuread_application" "reports" {
  display_name     = "app-uvu-it3200-${var.student_name}"
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "reports" {
  client_id = azuread_application.reports.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "reports" {
  application_id = azuread_application.reports.id
  display_name   = "temporary-lab-secret"
  end_date       = timeadd(timestamp(), "168h")

  lifecycle {
    ignore_changes = [end_date]
  }
}