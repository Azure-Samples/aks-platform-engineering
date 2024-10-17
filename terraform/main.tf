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

  azure_addons = {
    enable_azure_crossplane_upbound_provider = var.infrastructure_provider == "crossplane" ? true : false
    enable_cluster_api_operator              = var.infrastructure_provider == "capz" ? true : false
  }

  oss_addons = {
    enable_argocd                          = try(var.addons.enable_argocd, true) # installed by default
    enable_argo_rollouts                   = try(var.addons.enable_argo_rollouts, true) # installed by default
    enable_argo_events                     = try(var.addons.enable_argo_events, true) # installed by default
    enable_argo_workflows                  = try(var.addons.enable_argo_workflows, true) # installed by default
    enable_cluster_proportional_autoscaler = try(var.addons.enable_cluster_proportional_autoscaler, false)
    enable_cert_manager                    = var.infrastructure_provider == "capz" || try(var.addons.enable_cert_manager,false) ? true : false
    enable_gatekeeper                      = try(var.addons.enable_gatekeeper, false)
    enable_gpu_operator                    = try(var.addons.enable_gpu_operator, false)
    enable_ingress_nginx                   = try(var.addons.enable_ingress_nginx, false)
    enable_kargo                           = try(var.addons.enable_kargo, true) # installed by default 
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
  name                = "backstage_plugin_catalog"
  server_id         = azurerm_postgresql_flexible_server.backstagedbserver.id
  charset             = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  name                = "AllowAll_2024-10-16_11-52-53"
  server_id = azurerm_postgresql_flexible_server.backstagedbserver.id
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
}

# Define the OAuth2 permissions (redirect URIs)
resource "azuread_application_redirect_uris" "backstage_redirect_uri" {
  application_id = "/applications/${azuread_application.backstage-app.object_id}"
  type                  = "Web"
  redirect_uris         = ["https://${azurerm_public_ip.backstage_public_ip.ip_address}/api/auth/microsoft/handler/frame"]
}
# Define the service principal
resource "azuread_service_principal" "backstage-app-sp" {
  client_id = azuread_application.backstage-app.application_id
}

# Define the service principal password
resource "azuread_service_principal_password" "backstage-sp-password" {
  service_principal_id = azuread_service_principal.backstage-app-sp.id
  end_date             = "2099-01-01T00:00:00Z"
}


# Output the necessary variables
output "azure_client_id" {
  value = azuread_application.backstage-app.application_id
}

output "azure_client_secret" {
  value = azuread_service_principal_password.backstage-sp-password.value
  sensitive = true
}

output "azure_tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

################################################################################
# AKS: Public IP for predictable backstage service & redirect URI
################################################################################

resource "azurerm_public_ip" "backstage_public_ip" {
  name                = "backstage-public-ip"
  location            = azurerm_resource_group.this.location
  resource_group_name = module.aks.node_resource_group
  allocation_method   = "Static"
  sku                 = "Standard"
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
    chart_version = "7.5.2"
  }
}

################################################################################
# Ingress Controller - NGINX: Bootstrap
################################################################################

resource "helm_release" "nginx" {
  depends_on = [module.aks]
  name       = "nginx"
  repository = "https://helm-charts.wikimedia.org/stable/"
  chart      = "raw"
  version    = "0.3.0"
  for_each = { for manifest in provider::kubernetes::manifest_decode_multi(file("${path.module}/nginx.yaml"))  : "${lower(manifest.kind)}-${manifest.metadata.name}" => manifest }
  values = [
      <<-EOF
      resources:
     - apiVersion: v1
kind: Namespace
metadata:
  labels:
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
  name: ingress-nginx
---
- apiVersion: v1
automountServiceAccountToken: true
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx
  namespace: ingress-nginx
---
- apiVersion: v1
automountServiceAccountToken: true
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: admission-webhook
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx-admission
  namespace: ingress-nginx
---
- apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx
  namespace: ingress-nginx
rules:
- apiGroups:
  - ""
  resources:
  - namespaces
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - configmaps
  - pods
  - secrets
  - endpoints
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - services
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - networking.k8s.io
  resources:
  - ingresses
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - networking.k8s.io
  resources:
  - ingresses/status
  verbs:
  - update
- apiGroups:
  - networking.k8s.io
  resources:
  - ingressclasses
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - coordination.k8s.io
  resourceNames:
  - ingress-nginx-leader
  resources:
  - leases
  verbs:
  - get
  - update
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - create
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
  - patch
- apiGroups:
  - discovery.k8s.io
  resources:
  - endpointslices
  verbs:
  - list
  - watch
  - get
---
- apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  labels:
    app.kubernetes.io/component: admission-webhook
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx-admission
  namespace: ingress-nginx
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - create
---
- apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx
rules:
- apiGroups:
  - ""
  resources:
  - configmaps
  - endpoints
  - nodes
  - pods
  - secrets
  - namespaces
  verbs:
  - list
  - watch
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - services
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - networking.k8s.io
  resources:
  - ingresses
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - events
  verbs:
  - create
  - patch
- apiGroups:
  - networking.k8s.io
  resources:
  - ingresses/status
  verbs:
  - update
- apiGroups:
  - networking.k8s.io
  resources:
  - ingressclasses
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - discovery.k8s.io
  resources:
  - endpointslices
  verbs:
  - list
  - watch
  - get
---
- apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app.kubernetes.io/component: admission-webhook
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx-admission
rules:
- apiGroups:
  - admissionregistration.k8s.io
  resources:
  - validatingwebhookconfigurations
  verbs:
  - get
  - update
---
- apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx
  namespace: ingress-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ingress-nginx
subjects:
- kind: ServiceAccount
  name: ingress-nginx
  namespace: ingress-nginx
---
- apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    app.kubernetes.io/component: admission-webhook
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx-admission
  namespace: ingress-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ingress-nginx-admission
subjects:
- kind: ServiceAccount
  name: ingress-nginx-admission
  namespace: ingress-nginx
---
- apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ingress-nginx
subjects:
- kind: ServiceAccount
  name: ingress-nginx
  namespace: ingress-nginx
---
- apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app.kubernetes.io/component: admission-webhook
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx-admission
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ingress-nginx-admission
subjects:
- kind: ServiceAccount
  name: ingress-nginx-admission
  namespace: ingress-nginx
---
- apiVersion: v1
data: null
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx-controller
  namespace: ingress-nginx
---
- apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  externalTrafficPolicy: Local
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - appProtocol: http
    name: http
    port: 80
    protocol: TCP
    targetPort: http
  - appProtocol: https
    name: https
    port: 443
    protocol: TCP
    targetPort: https
  selector:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
  type: LoadBalancer
---
- apiVersion: v1
kind: Service
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx-controller-admission
  namespace: ingress-nginx
spec:
  ports:
  - appProtocol: https
    name: https-webhook
    port: 443
    targetPort: webhook
  selector:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
  type: ClusterIP
---
- apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  minReadySeconds: 0
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app.kubernetes.io/component: controller
      app.kubernetes.io/instance: ingress-nginx
      app.kubernetes.io/name: ingress-nginx
  strategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app.kubernetes.io/component: controller
        app.kubernetes.io/instance: ingress-nginx
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
        app.kubernetes.io/version: 1.12.0-beta.0
    spec:
      containers:
      - args:
        - /nginx-ingress-controller
        - --publish-service=$(POD_NAMESPACE)/ingress-nginx-controller
        - --election-id=ingress-nginx-leader
        - --controller-class=k8s.io/ingress-nginx
        - --ingress-class=nginx
        - --configmap=$(POD_NAMESPACE)/ingress-nginx-controller
        - --validating-webhook=:8443
        - --validating-webhook-certificate=/usr/local/certificates/cert
        - --validating-webhook-key=/usr/local/certificates/key
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: LD_PRELOAD
          value: /usr/local/lib/libmimalloc.so
        image: registry.k8s.io/ingress-nginx/controller:v1.12.0-beta.0@sha256:9724476b928967173d501040631b23ba07f47073999e80e34b120e8db5f234d5
        imagePullPolicy: IfNotPresent
        lifecycle:
          preStop:
            exec:
              command:
              - /wait-shutdown
        livenessProbe:
          failureThreshold: 5
          httpGet:
            path: /healthz
            port: 10254
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 1
        name: controller
        ports:
        - containerPort: 80
          name: http
          protocol: TCP
        - containerPort: 443
          name: https
          protocol: TCP
        - containerPort: 8443
          name: webhook
          protocol: TCP
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /healthz
            port: 10254
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 1
        resources:
          requests:
            cpu: 100m
            memory: 90Mi
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET_BIND_SERVICE
            drop:
            - ALL
          readOnlyRootFilesystem: false
          runAsGroup: 82
          runAsNonRoot: true
          runAsUser: 101
          seccompProfile:
            type: RuntimeDefault
        volumeMounts:
        - mountPath: /usr/local/certificates/
          name: webhook-cert
          readOnly: true
      dnsPolicy: ClusterFirst
      nodeSelector:
        kubernetes.io/os: linux
      serviceAccountName: ingress-nginx
      terminationGracePeriodSeconds: 300
      volumes:
      - name: webhook-cert
        secret:
          secretName: ingress-nginx-admission
---
- apiVersion: batch/v1
kind: Job
metadata:
  labels:
    app.kubernetes.io/component: admission-webhook
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx-admission-create
  namespace: ingress-nginx
spec:
  template:
    metadata:
      labels:
        app.kubernetes.io/component: admission-webhook
        app.kubernetes.io/instance: ingress-nginx
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
        app.kubernetes.io/version: 1.12.0-beta.0
      name: ingress-nginx-admission-create
    spec:
      containers:
      - args:
        - create
        - --host=ingress-nginx-controller-admission,ingress-nginx-controller-admission.$(POD_NAMESPACE).svc
        - --namespace=$(POD_NAMESPACE)
        - --secret-name=ingress-nginx-admission
        env:
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        image: registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.4.4@sha256:a9f03b34a3cbfbb26d103a14046ab2c5130a80c3d69d526ff8063d2b37b9fd3f
        imagePullPolicy: IfNotPresent
        name: create
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsGroup: 65532
          runAsNonRoot: true
          runAsUser: 65532
          seccompProfile:
            type: RuntimeDefault
      nodeSelector:
        kubernetes.io/os: linux
      restartPolicy: OnFailure
      serviceAccountName: ingress-nginx-admission
---
- apiVersion: batch/v1
kind: Job
metadata:
  labels:
    app.kubernetes.io/component: admission-webhook
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx-admission-patch
  namespace: ingress-nginx
spec:
  template:
    metadata:
      labels:
        app.kubernetes.io/component: admission-webhook
        app.kubernetes.io/instance: ingress-nginx
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
        app.kubernetes.io/version: 1.12.0-beta.0
      name: ingress-nginx-admission-patch
    spec:
      containers:
      - args:
        - patch
        - --webhook-name=ingress-nginx-admission
        - --namespace=$(POD_NAMESPACE)
        - --patch-mutating=false
        - --secret-name=ingress-nginx-admission
        - --patch-failure-policy=Fail
        env:
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        image: registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.4.4@sha256:a9f03b34a3cbfbb26d103a14046ab2c5130a80c3d69d526ff8063d2b37b9fd3f
        imagePullPolicy: IfNotPresent
        name: patch
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsGroup: 65532
          runAsNonRoot: true
          runAsUser: 65532
          seccompProfile:
            type: RuntimeDefault
      nodeSelector:
        kubernetes.io/os: linux
      restartPolicy: OnFailure
      serviceAccountName: ingress-nginx-admission
---
- apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: nginx
spec:
  controller: k8s.io/ingress-nginx
---
- apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  labels:
    app.kubernetes.io/component: admission-webhook
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.12.0-beta.0
  name: ingress-nginx-admission
webhooks:
- admissionReviewVersions:
  - v1
  clientConfig:
    service:
      name: ingress-nginx-controller-admission
      namespace: ingress-nginx
      path: /networking/v1/ingresses
      port: 443
  failurePolicy: Fail
  matchPolicy: Equivalent
  name: validate.nginx.ingress.kubernetes.io
  rules:
  - apiGroups:
    - networking.k8s.io
    apiVersions:
    - v1
    operations:
    - CREATE
    - UPDATE
    resources:
    - ingresses
  sideEffects: None

      EOF
  ]
}

################################################################################
# TLS Cert Management - CertManager: Bootstrap
################################################################################

resource "helm_release" "cert_manager" {
  depends_on = [module.aks]
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.15.1"

  set {
    name  = "installCRDs"
    value = "true"
  }
}

################################################################################
# Letsencryptdeployment - CertManager: Bootstrap
################################################################################

resource "helm_release" "cluster_issuer" {
  depends_on = [helm_release.cert_manager]
  name       = "cluster-issuer"
  repository = "https://helm-charts.wikimedia.org/stable/"
  chart      = "raw"
  version    = "0.3.0"
  values = [
    <<-EOF
    resources:
    apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
    EOF
  ]
}

################################################################################
# Backstage: Bootstrap
################################################################################
resource "kubernetes_namespace" "backstage_nammespace" {
  depends_on = [module.aks]
  metadata {
    name = "backstage"
  }
}

resource "helm_release" "backstage" {
  name       = "backstage"
  repository = "oci://oowcontainerimages.azurecr.io/helm"
  chart      = "backstagechart"
  version    = "0.1.0"

  set {
    name  = "image.repository"
    value = "oowcontainerimages.azurecr.io/backstage"
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
    value = azurerm_public_ip.backstage_public_ip.ip_address
  }
  set {
    name  = "image.tag"
    value = "v1"
  }

  set {
    name  = "env.BASE_URL"
    value = "https://${azurerm_public_ip.backstage_public_ip.ip_address}"
  }

  set {
    name  = "env.POSTGRES_HOST"
    value = azurerm_postgresql_flexible_server.backstagedbserver.fqdn
  }

  set {
    name  = "env.POSTGRES_PORT"
    value = "5432"
  }

  set {
    name  = "env.POSTGRES_USER"
    value = azurerm_postgresql_flexible_server.backstagedbserver.administrator_login
  }

  set {
    name  = "env.POSTGRES_PASSWORD"
    value = azurerm_postgresql_flexible_server.backstagedbserver.administrator_password
  }

  set {
    name  = "env.POSTGRES_DB"
    value = azurerm_postgresql_flexible_server_database.backstage_plugin_catalog.name
  }

  set {
    name  = "env.AZURE_CLIENT_ID"
    value = azuread_application.backstage-app.client_id
  }

  set {
    name  = "env.AZURE_CLIENT_SECRET"
    value = azuread_service_principal_password.backstage-sp-password.value
  }

  set {
    name  = "env.AZURE_TENANT_ID"
    value = data.azurerm_client_config.current.tenant_id
  }
   # Add Ingress configuration for Backstage
  set {
    name  = "ingress.enabled"
    value = "true"
  }

  set {
    name  = "ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = "letsencrypt-prod"
  }

  set {
    name  = "ingress.hosts[0].host"
    value = azurerm_public_ip.backstage_public_ip.ip_address
  }

  set {
    name  = "ingress.hosts[0].paths[0].path"
    value = "/"
  }

  set {
    name  = "ingress.hosts[0].paths[0].pathType"
    value = "Prefix"
  }

  set {
    name  = "ingress.tls[0].hosts[0]"
    value =   azurerm_public_ip.backstage_public_ip.ip_address
  }

  set {
    name  = "ingress.tls[0].secretName"
    value = "backstage-tls"
  }
}