output "subscription_id" {
  description = "Specifies the subscription id."
  value = data.azurerm_subscription.current.id
}

output "tenant" {
  description = "Specifies the tenant id."
  value       = data.azurerm_client_config.current.tenant_id 
}

output "service_principal_client_id" {
  description = "Specifies the client id of the service principal."
  value = var.use_service_principal ? azuread_service_principal.service_principal[0].client_id : null
}

output "service_principal_password" {
  description = "Specifies the password for the service principal."
  value = var.use_service_principal ? azuread_service_principal_password.service_principal_password[0].value : null
  sensitive = true
}