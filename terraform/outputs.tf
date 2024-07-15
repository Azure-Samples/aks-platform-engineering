output "subscription_id" {
  description = "Specifies the subscription id."
  value       = data.azurerm_subscription.current.id
}

output "tenant" {
  description = "Specifies the tenant id."
  value       = data.azurerm_client_config.current.tenant_id
}