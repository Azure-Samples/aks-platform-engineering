output "subscription_id" {
  description = "Specifies the subscription id."
  value       = data.azurerm_subscription.current.subscription_id
}

output "tenant" {
  description = "Specifies the tenant id."
  value       = data.azurerm_client_config.current.tenant_id
}

output "akspe_client_id" {
  description = "Specifies the client id used for user MSI to use for workload identity auth with CAPZ/Crossplane."
  value       = azurerm_user_assigned_identity.akspe.client_id
}