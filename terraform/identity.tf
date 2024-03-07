resource "azurerm_user_assigned_identity" "capz" {
  count               = try(var.addons.enable_cluster_api_operator, false) ? 1 : 0
  name                = "capz"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

resource "azurerm_role_assignment" "capz_role_assignment" {
  count               = try(var.addons.enable_cluster_api_operator, false) ? 1 : 0
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Owner"
  principal_id         = azurerm_user_assigned_identity.capz[0].principal_id
}

resource "azurerm_federated_identity_credential" "capz" {
  count               = try(var.addons.enable_cluster_api_operator, false) ? 1 : 0
  depends_on          = [module.aks]
  name                = "capz-manager-credential"
  resource_group_name = azurerm_resource_group.this.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.capz[0].id
  subject             = "system:serviceaccount:azure-infrastructure-system:capz-manager"
}
