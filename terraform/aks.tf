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
    enable_azure_crossplane_provider         = try(var.addons.enable_azure_crossplane_provider, false)
    enable_azure_crossplane_upbound_provider = try(var.addons.enable_azure_crossplane_upbound_provider, false)
  }
  oss_addons = {
    enable_argocd                            = try(var.addons.enable_argocd, false)
    enable_argo_rollouts                     = try(var.addons.enable_argo_rollouts, false)
    enable_argo_events                       = try(var.addons.enable_argo_events, false)
    enable_argo_workflows                    = try(var.addons.enable_argo_workflows, false)
    enable_cluster_proportional_autoscaler   = try(var.addons.enable_cluster_proportional_autoscaler, false)
    enable_gatekeeper                        = try(var.addons.enable_gatekeeper, false)
    enable_gpu_operator                      = try(var.addons.enable_gpu_operator, false)
    enable_ingress_nginx                     = try(var.addons.enable_ingress_nginx, false)
    enable_kyverno                           = try(var.addons.enable_kyverno, false)
    enable_kube_prometheus_stack             = try(var.addons.enable_kube_prometheus_stack, false)
    enable_metrics_server                    = try(var.addons.enable_metrics_server, false)
    enable_prometheus_adapter                = try(var.addons.enable_prometheus_adapter, false)
    enable_secrets_store_csi_driver          = try(var.addons.enable_secrets_store_csi_driver, false)
    enable_vpa                               = try(var.addons.enable_vpa, false)
    enable_crossplane                        = try(var.addons.enable_crossplane, false)
    enable_crossplane_kubernetes_provider    = try(var.addons.enable_crossplane_kubernetes_provider, false)
    enable_crossplane_helm_provider          = try(var.addons.enable_crossplane_helm_provider, false)
  }
  addons = merge(azure_addons, local.oss_addons)

  cluster_metadata = merge(local.addons_metadata, local.workloads_metadata)

  addons_metadata = {
    addons_repo_url      = local.gitops_addons_url
    addons_repo_basepath = local.gitops_addons_basepath
    addons_repo_path     = local.gitops_addons_path
    addons_repo_revision = local.gitops_addons_revision
  }

  workloads_metadata = {
    workload_repo_url      = "${var.gitops_workload_org}/${var.gitops_workload_repo}"
    workload_repo_basepath = var.gitops_workload_basepath
    workload_repo_path     = var.gitops_workload_path
    workload_repo_revision = var.gitops_workload_revision
  }

  argocd_apps = {
    addons    = file("${path.module}/bootstrap/addons.yaml")
    workloads = file("${path.module}/bootstrap/workloads.yaml")
  }

  tags = {
    Blueprint  = local.name
    GithubRepo = "github.com/gitops-bridge-dev/gitops-bridge"
  }
}

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
# AKS: Module
################################################################################

module "aks" {
  source                            = "github.com/Azure/terraform-azurerm-aks.git?ref=632deec"
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
# GitOps Bridge: Bootstrap
################################################################################
module "gitops_bridge_bootstrap" {
  depends_on = [module.aks]
  source     = "gitops-bridge-dev/gitops-bridge/helm"

  cluster = {
    cluster_name = module.aks.aks_name
    environment  = local.environment
    metadata     = merge(local.cluster_metadata,
      {
        service_principal_client_id = azuread_service_principal.service_principal.client_id
        service_principal_password  = azuread_service_principal_password.service_principal_password.value
      }
    )       
    addons       = local.addons
  }
  apps = local.argocd_apps
  argocd = {
    namespace = local.argocd_namespace
  }
}

################################################################################
# Service Principal: Creation
################################################################################
data "azuread_client_config" "current" {}
data "azurerm_subscription" "current" {}

resource "azuread_application" "registered_application" {
  display_name = var.registered_application_name
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "service_principal" {
  client_id                    = azuread_application.registered_application.client_id
  app_role_assignment_required = true
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "time_rotating" "service_principal_credentials_time_rotating" {
  rotation_years = 2
}

resource "azuread_service_principal_password" "service_principal_password" {
  service_principal_id = azuread_service_principal.service_principal.object_id
  rotate_when_changed = {
    rotation = time_rotating.service_principal_credentials_time_rotating.id
  }
}
resource "azurerm_role_assignment" "service_principal_subscription_owner_role_assignment" {
  scope                            = data.azurerm_subscription.current.id
  role_definition_name             = "Owner"
  principal_id                     = azuread_service_principal.service_principal.object_id
  skip_service_principal_aad_check = true
}