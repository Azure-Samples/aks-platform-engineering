resource "azurerm_user_assigned_identity" "capz" {
  name                = "capz"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

resource "azurerm_role_assignment" "capz_role_assignment" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.capz.principal_id
}

resource "azurerm_federated_identity_credential" "capz" {
  depends_on          = [module.aks]
  name                = "capz-manager-credential"
  resource_group_name = azurerm_resource_group.this.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.capz.id
  subject             = "system:serviceaccount:azure-infrastructure-system:capz-manager"
}

resource "azurerm_federated_identity_credential" "service_operator" {
  depends_on          = [module.aks]
  name                = "serviceoperator"
  resource_group_name = azurerm_resource_group.this.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.capz.id
  subject             = "system:serviceaccount:azure-infrastructure-system:azureserviceoperator-default"
}
