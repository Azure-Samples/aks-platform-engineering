locals {
  name        = local.environment
  environment = "control-plane"
  location    = var.location
  

  #cluster_version = var.kubernetes_version

  gitops_addons_url      = "${var.gitops_addons_org}/${var.gitops_addons_repo}"
  gitops_addons_basepath = var.gitops_addons_basepath
  gitops_addons_path     = var.gitops_addons_path
  gitops_addons_revision = var.gitops_addons_revision


  argocd_namespace = "argocd"

  github_token = var.github_token
  build_backstage = var.build_backstage

  azure_addons = {
    enable_azure_crossplane_upbound_provider = var.infrastructure_provider == "crossplane" ? true : false
    enable_cluster_api_operator              = var.infrastructure_provider == "capz" ? true : false
  }

  oss_addons = {
    enable_argocd                          = try(var.addons.enable_argocd, true) # installed by default
    argocd_chart_version                   = var.addons_versions[0].argocd_chart_version
    enable_argo_rollouts                   = try(var.addons.enable_argo_rollouts, true) # installed by default
    argo_rollouts_chart_version            = var.addons_versions[0].argo_rollouts_chart_version
    enable_argo_events                     = try(var.addons.enable_argo_events, true) # installed by default
    enable_argo_workflows                  = try(var.addons.enable_argo_workflows, true) # installed by default
    enable_cluster_proportional_autoscaler = try(var.addons.enable_cluster_proportional_autoscaler, false)
    enable_cert_manager                    = var.infrastructure_provider == "capz" || try(var.addons.enable_cert_manager,false) ? true : false
    enable_gatekeeper                      = try(var.addons.enable_gatekeeper, false)
    enable_gpu_operator                    = try(var.addons.enable_gpu_operator, false)
    enable_ingress_nginx                   = try(var.addons.enable_ingress_nginx, false)
    enable_kargo                           = try(var.addons.enable_kargo, true) # installed by default
    kargo_chart_version                    = var.addons_versions[0].kargo_chart_version
    enable_kyverno                         = try(var.addons.enable_kyverno, false)
    enable_kube_prometheus_stack           = try(var.addons.enable_kube_prometheus_stack, false)
    enable_metrics_server                  = try(var.addons.enable_metrics_server, false)
    enable_prometheus_adapter              = try(var.addons.enable_prometheus_adapter, false)
    enable_secrets_store_csi_driver        = try(var.addons.enable_secrets_store_csi_driver, false)
    enable_vpa                             = try(var.addons.enable_vpa, false)
    enable_crossplane                      = var.infrastructure_provider == "crossplane" ? true : false
    enable_crossplane_helm_provider        = var.infrastructure_provider == "crossplane" ? true : false
    enable_crossplane_kubernetes_provider  = var.infrastructure_provider == "crossplane" ? true : false
  }
  addons = merge(local.azure_addons, local.oss_addons)

  cluster_metadata = merge(local.environment_metadata, local.addons_metadata)

  environment_metadata = {
    infrastructure_provider = var.infrastructure_provider
    akspe_identity_id        = azurerm_user_assigned_identity.akspe.client_id
    git_public_ssh_key      = var.git_public_ssh_key
  }

  addons_metadata = {
    addons_repo_url      = local.gitops_addons_url
    addons_repo_basepath = local.gitops_addons_basepath
    addons_repo_path     = local.gitops_addons_path
    addons_repo_revision = local.gitops_addons_revision
  }

  argocd_apps = {
    addons    = file("${path.module}/bootstrap/addons.yaml")
  }

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/gitops-bridge-dev/gitops-bridge"
  }
}

data "azurerm_subscription" "current" {}

################################################################################
# Resource Group: Resource
################################################################################
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

################################################################################
# Virtual Network: Module
################################################################################

module "network" {
  source              = "Azure/subnets/azurerm"
  version             = "1.0.0"
  resource_group_name = azurerm_resource_group.this.name
  subnets = {
    aks = {
      address_prefixes  = ["10.52.0.0/16"]
      service_endpoints = ["Microsoft.Storage"]
    }
  }
  virtual_network_address_space = ["10.52.0.0/16"]
  virtual_network_location      = azurerm_resource_group.this.location
  virtual_network_name          = "vnet1"
  virtual_network_tags          = var.tags
}

################################################################################
# Postgres: Module
################################################################################
resource "azurerm_postgresql_flexible_server" "backstagedbserver" {
  count = local.build_backstage ? 1 : 0
  name                = "backstage-postgresql-server"
  location            = var.location
  public_network_access_enabled = true
  administrator_password = "secretPassword123!"
  resource_group_name = azurerm_resource_group.this.name
  administrator_login = "psqladminun"
  sku_name = "GP_Standard_D4s_v3"
  version = "12"
  zone = 1
}

# Define the PostgreSQL database
resource "azurerm_postgresql_flexible_server_database" "backstage_plugin_catalog" {
  count = local.build_backstage ? 1 : 0
  name                = "backstage_plugin_catalog"
  server_id         = azurerm_postgresql_flexible_server.backstagedbserver[count.index].id
  charset             = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  count = local.build_backstage ? 1 : 0
  name                = "AllowAll"
  server_id = azurerm_postgresql_flexible_server.backstagedbserver[count.index].id
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}


################################################################################
# AKS: Module
################################################################################

module "aks" {
  source                            = "Azure/aks/azurerm"
  version                           = "9.1.0"
  resource_group_name               = azurerm_resource_group.this.name
  location                          = var.location
  kubernetes_version                = var.kubernetes_version
  orchestrator_version              = var.kubernetes_version
  role_based_access_control_enabled = var.role_based_access_control_enabled
  rbac_aad                          = var.rbac_aad
  prefix                            = var.prefix
  network_plugin                    = var.network_plugin
  vnet_subnet_id                    = lookup(module.network.vnet_subnets_name_id, "aks")
  os_disk_size_gb                   = var.os_disk_size_gb
  os_sku                            = var.os_sku
  sku_tier                          = var.sku_tier
  private_cluster_enabled           = var.private_cluster_enabled
  enable_auto_scaling               = var.enable_auto_scaling
  enable_host_encryption            = var.enable_host_encryption
  log_analytics_workspace_enabled   = var.log_analytics_workspace_enabled
  agents_min_count                  = var.agents_min_count
  agents_max_count                  = var.agents_max_count
  agents_count                      = null # Please set `agents_count` `null` while `enable_auto_scaling` is `true` to avoid possible `agents_count` changes.
  agents_max_pods                   = var.agents_max_pods
  agents_pool_name                  = "system"
  agents_availability_zones         = ["1", "2", "3"]
  agents_type                       = "VirtualMachineScaleSets"
  agents_size                       = var.agents_size
  monitor_metrics                   = {}
  azure_policy_enabled              = var.azure_policy_enabled
  microsoft_defender_enabled        = var.microsoft_defender_enabled
  tags                              = var.tags
  green_field_application_gateway_for_ingress = var.green_field_application_gateway_for_ingress
  create_role_assignments_for_application_gateway = var.create_role_assignments_for_application_gateway

  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  agents_labels = {
    "nodepool" : "defaultnodepool"
  }

  agents_tags = {
    "Agent" : "defaultnodepoolagent"
  }

  network_policy             = var.network_policy
  net_profile_dns_service_ip = var.net_profile_dns_service_ip
  net_profile_service_cidr   = var.net_profile_service_cidr

  network_contributor_role_assigned_subnet_ids = { "aks" = lookup(module.network.vnet_subnets_name_id, "aks") }

  depends_on = [module.network]
}




################################################################################
# Workload Identity: Module
################################################################################

resource "azurerm_user_assigned_identity" "akspe" {
  name                = "akspe"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}

resource "azurerm_role_assignment" "akspe_role_assignment" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Owner"
  principal_id         = azurerm_user_assigned_identity.akspe.principal_id
}

resource "azurerm_federated_identity_credential" "crossplane" {
  count               = var.infrastructure_provider == "crossplane" ? 1 : 0
  depends_on          = [module.aks]
  name                = "crossplane-provider-azure"
  resource_group_name = azurerm_resource_group.this.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.akspe.id
  subject             = "system:serviceaccount:crossplane-system:azure-provider"
}

resource "azurerm_federated_identity_credential" "capz" {
  count               = var.infrastructure_provider == "capz" ? 1 : 0
  depends_on          = [module.aks]
  name                = "capz-manager-credential"
  resource_group_name = azurerm_resource_group.this.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.akspe.id
  subject             = "system:serviceaccount:azure-infrastructure-system:capz-manager"
}

resource "azurerm_federated_identity_credential" "service_operator" {
  count               = var.infrastructure_provider == "capz" ? 1 : 0
  depends_on          = [module.aks]
  name                = "serviceoperator"
  resource_group_name = azurerm_resource_group.this.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.akspe.id
  subject             = "system:serviceaccount:azure-infrastructure-system:azureserviceoperator-default"
}




resource "azuread_application" "backstage-app" {
  count = local.build_backstage ? 1 : 0
  display_name = "Backstage"

  app_role {
    id              = uuid() # Generate a unique ID for the role
    allowed_member_types = ["User"]
    description          = "Allows the app to read the profile of signed-in users."
    display_name         = "User.Read"
    value                = "User.Read"
  }

  app_role {
    id              = uuid() # Generate a unique ID for the role
    allowed_member_types = ["User"]
    description          = "Allows the app to read all users' full profiles."
    display_name         = "User.Read.All"
    value                = "User.Read.All"
  }

  app_role {
    id              = uuid() # Generate a unique ID for the role
    allowed_member_types = ["User"]
    description          = "Allows the app to read the memberships of all groups."
    display_name         = "GroupMember.Read.All"
    value                = "GroupMember.Read.All"
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph API

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }

    resource_access {
      id   = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All
      type = "Role"
    }

    resource_access {
      id   = "98830695-27a2-44f7-8c18-0c3ebc9698f6" # GroupMember.Read.All
      type = "Role"
    }

    resource_access {
      id   = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0" # email
      type = "Scope"
    }

    resource_access {
      id   = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182" # offline_access
      type = "Scope"
    }

    resource_access {
      id = "e383f46e-2787-4529-855e-0e479a3ffac0" # mail.send
      type = "Scope"
    }

    resource_access {
      id   = "37f7f235-527c-4136-accd-4a02d197296e" # openid
      type = "Scope"
    }
  }
}


# Define the OAuth2 permissions (redirect URIs)
resource "azuread_application_redirect_uris" "backstage_redirect_uri" {
  count = local.build_backstage ? 1 : 0
  application_id = "/applications/${azuread_application.backstage-app[count.index].object_id}"
  type                  = "Web"
  redirect_uris         = ["https://${azurerm_public_ip.backstage_public_ip[count.index].ip_address}/api/auth/microsoft/handler/frame"]
}
# Define the service principal
resource "azuread_service_principal" "backstage-app-sp" {
  count = local.build_backstage ? 1 : 0
  client_id = azuread_application.backstage-app[count.index].application_id
}

# Define the service principal password
resource "azuread_service_principal_password" "backstage-sp-password" {
  count = local.build_backstage ? 1 : 0
  service_principal_id = azuread_service_principal.backstage-app-sp[count.index].id
  end_date             = "2099-01-01T00:00:00Z"
}

resource "null_resource" "ascii_art" {
  count = local.build_backstage ? 1 : 0
  depends_on = [ azuread_service_principal_password.backstage-sp-password ]
  provisioner "local-exec" {
    command = <<EOT
echo "    _      _     ______  _____   _______ "
echo "   / \\   | |   |  ____||  __ \\|__   __|"
echo "  / _ \\  | |   | |__   | |__) |   | |   "
echo " / ___ \\ | |   |  __|  |  _  /    | |   "
echo "/_/   \\_\|_|___| |____ | | \\\    | |   "
echo "        \\_\\_____|______||_| \_\  |_|   "
echo ""
echo ""
echo "Please grant admin consent on app registration now to avoid waiting for the 1 hour schedule post backstage chart deployment."
EOT
  }
}

# Output the necessary variables
output "azure_client_id" {
  value = azuread_application.backstage-app[0].application_id
}

output "azure_client_secret" {
  value = azuread_service_principal_password.backstage-sp-password[0].value
  sensitive = true
}

output "azure_tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

################################################################################
# AKS: Public IP for predictable backstage service & redirect URI
################################################################################

resource "azurerm_public_ip" "backstage_public_ip" {
  count = local.build_backstage ? 1 : 0
  name                = "backstage-public-ip"
  location            = azurerm_resource_group.this.location
  resource_group_name = module.aks.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
}

################################################################################
# Backstage: Service Account & Secret
################################################################################
resource "kubernetes_namespace" "backstage_nammespace" {
  count = local.build_backstage ? 1 : 0
  depends_on = [module.aks]
  metadata {
    name = "backstage"
  }
}
resource "kubernetes_service_account" "backstage_service_account" {
  count = local.build_backstage ? 1 : 0
  depends_on = [ kubernetes_namespace.backstage_nammespace ]
  metadata {
    name      = "backstage-service-account"
    namespace = "backstage"
    
  }
  
}

resource "kubernetes_role" "backstage_pod_reader" {
  count = local.build_backstage ? 1 : 0
  depends_on = [ kubernetes_service_account.backstage_service_account ]
  metadata {
    name      = "backstage-pod-reader"
    namespace = "backstage"
  }

  rule {
    api_groups = [""]
    resources  = [
      "pods",
      "services",
      "replicationcontrollers",
      "persistentvolumeclaims",
      "configmaps",
      "secrets",
      "events",
      "pods/log",
      "pods/status",
    ]
    verbs = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "backstage_role_binding" {
  count = local.build_backstage ? 1 : 0
  depends_on = [kubernetes_role.backstage_pod_reader]
  metadata {
    name      = "backstage-role-binding"
    namespace = "backstage"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.backstage_pod_reader[count.index].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.backstage_service_account[count.index].metadata[0].name
    namespace = kubernetes_service_account.backstage_service_account[count.index].metadata[0].namespace
  }
}

resource "kubernetes_secret" "backstage_service_account_secret" {
  count = local.build_backstage ? 1 : 0
  depends_on = [ kubernetes_service_account.backstage_service_account ]
  metadata {
      annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.backstage_service_account[count.index].metadata[0].name
    }
    name      = "backstage-service-account-secret"
    namespace = kubernetes_service_account.backstage_service_account[count.index].metadata[0].namespace
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

resource "null_resource" "get_cluster_info" {
  provisioner "local-exec" {
    command = "kubectl cluster-info | grep 'Kubernetes control plane is running at' | awk '{print $NF}' | tr -d '\n' > cluster_info.txt"
    environment = {
      KUBECONFIG = "${path.module}/kubeconfig"
    }
    interpreter = ["bash", "-c"]
  }

  triggers = {
    always_run = "${timestamp()}"
  }
}



################################################################################
# GitOps Bridge: Private ssh keys for git
################################################################################
resource "kubernetes_namespace" "argocd_namespace" {
  depends_on = [module.aks]
  metadata {
    name = "argocd"
  }
}

resource "kubernetes_secret" "git_secrets" {
  depends_on = [kubernetes_namespace.argocd_namespace]
  for_each = {
    git-addons = {
      type          = "git"
      url           = var.gitops_addons_org
      # sshPrivateKey = file(pathexpand(var.git_private_ssh_key))
    }
  }
  metadata {
    name      = each.key
    namespace = kubernetes_namespace.argocd_namespace.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repo-creds"
    }
  }
  data = each.value
}


################################################################################
# GitOps Bridge: Bootstrap
################################################################################
module "gitops_bridge_bootstrap" {
  depends_on = [module.aks]
  source     = "gitops-bridge-dev/gitops-bridge/helm"

  cluster = {
    cluster_name = module.aks.aks_name
    environment  = local.environment
    metadata = merge(local.cluster_metadata,
    {
        kubelet_identity_client_id = module.aks.kubelet_identity[0].client_id
        subscription_id            = data.azurerm_subscription.current.subscription_id
        tenant_id                  = data.azurerm_subscription.current.tenant_id
    })
    addons = local.addons
  }
  apps = local.argocd_apps
  argocd = {
    namespace     = local.argocd_namespace
    chart_version = var.addons_versions[0].argocd_chart_version
  }
}


################################################################################
# Backstage: Bootstrap
################################################################################

resource "kubernetes_secret" "tls_secret" {
  count = local.build_backstage ? 1 : 0
  depends_on = [kubernetes_namespace.backstage_nammespace]

  metadata {
    name      = "my-tls-secret"
    namespace = kubernetes_namespace.backstage_nammespace[count.index].metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = file("tls.crt")  # Adjust the path accordingly
    "tls.key" = file("tls.key")  # Adjust the path accordingly
  }
}



resource "helm_release" "backstage" {
  count = local.build_backstage ? 1 : 0
  depends_on = [ kubernetes_secret.tls_secret ]
  name       = "backstage"
  repository = "oci://oowcontainerimages.azurecr.io/helm"
  chart      = "backstagechart"
  version    = "0.1.0"

  set {
    name  = "image.repository"
    value = "oowcontainerimages.azurecr.io/backstage"
  }
    set {
    name  = "image.tag"
    value = "v2"
  }
    set {
    name  = "env.K8S_CLUSTER_NAME"
    value = module.aks.aks_name
  }

      set {
    name  = "env.K8S_CLUSTER_URL"
    value = "https://${module.aks.aks_name}"
  }

  set {
    name  = "env.K8S_SERVICE_ACCOUNT_TOKEN"
    value = kubernetes_secret.backstage_service_account_secret[count.index].data.token
  }

    set {
    name  = "env.GITHUB_TOKEN"
    value = local.github_token
  }

  set {
    name = "env.GITOPS_REPO"
    value = local.gitops_addons_url
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = module.aks.node_resource_group
  }

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-ipv4"
    value = azurerm_public_ip.backstage_public_ip[count.index].ip_address
  }
  set {
    name  = "image.tag"
    value = "v1"
  }

  set {
    name  = "env.BASE_URL"
    value = "https://${azurerm_public_ip.backstage_public_ip[count.index].ip_address}"
  }

  set {
    name  = "env.POSTGRES_HOST"
    value = azurerm_postgresql_flexible_server.backstagedbserver[count.index].fqdn
  }

  set {
    name  = "env.POSTGRES_PORT"
    value = "5432"
  }

  set {
    name  = "env.POSTGRES_USER"
    value = azurerm_postgresql_flexible_server.backstagedbserver[count.index].administrator_login
  }

  set {
    name  = "env.POSTGRES_PASSWORD"
    value = azurerm_postgresql_flexible_server.backstagedbserver[count.index].administrator_password
  }

  set {
    name  = "env.POSTGRES_DB"
    value = azurerm_postgresql_flexible_server_database.backstage_plugin_catalog[count.index].name
  }

  set {
    name  = "env.AZURE_CLIENT_ID"
    value = azuread_application.backstage-app[count.index].client_id
  }

  set {
    name  = "env.AZURE_CLIENT_SECRET"
    value = azuread_service_principal_password.backstage-sp-password[count.index].value
  }

  set {
    name  = "env.AZURE_TENANT_ID"
    value = data.azurerm_client_config.current.tenant_id
  }
    set {
    name  = "podAnnotations.backstage\\.io/kubernetes-id"
    value = "${module.aks.aks_name}-component"
  }
  
  set {
    name  = "labels.kubernetesId"
    value = "${module.aks.aks_name}-component"
  }
}