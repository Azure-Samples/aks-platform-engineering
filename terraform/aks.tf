locals {
  name        = local.environment
  environment = "control-plane"
  region      = var.region

  #cluster_version = var.kubernetes_version

  gitops_addons_url      = "${var.gitops_addons_org}/${var.gitops_addons_repo}"
  gitops_addons_basepath = var.gitops_addons_basepath
  gitops_addons_path     = var.gitops_addons_path
  gitops_addons_revision = var.gitops_addons_revision

  argocd_namespace = "argocd"

  oss_addons = {
    enable_argocd                          = try(var.addons.enable_argocd, false)
    enable_argo_rollouts                   = try(var.addons.enable_argo_rollouts, false)
    enable_argo_events                     = try(var.addons.enable_argo_events, false)
    enable_argo_workflows                  = try(var.addons.enable_argo_workflows, false)
    enable_cluster_proportional_autoscaler = try(var.addons.enable_cluster_proportional_autoscaler, false)
    enable_gatekeeper                      = try(var.addons.enable_gatekeeper, false)
    enable_gpu_operator                    = try(var.addons.enable_gpu_operator, false)
    enable_ingress_nginx                   = try(var.addons.enable_ingress_nginx, false)
    enable_kyverno                         = try(var.addons.enable_kyverno, false)
    enable_kube_prometheus_stack           = try(var.addons.enable_kube_prometheus_stack, false)
    enable_metrics_server                  = try(var.addons.enable_metrics_server, false)
    enable_prometheus_adapter              = try(var.addons.enable_prometheus_adapter, false)
    enable_secrets_store_csi_driver        = try(var.addons.enable_secrets_store_csi_driver, false)
    enable_vpa                             = try(var.addons.enable_vpa, false)
  }
  addons = local.oss_addons

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

module "aks" {
  source                            = "github.com/Azure/terraform-azurerm-aks.git?ref=be5ef5c3948b6305a0913d1f00b8eadcd01e7314"
  resource_group_name               = azurerm_resource_group.this.name
  location                          = var.region
  kubernetes_version                = var.kubernetes_version
  orchestrator_version              = var.kubernetes_version
  role_based_access_control_enabled = true
  rbac_aad                          = false
  prefix                            = "gitops"
  network_plugin                    = "azure"
  vnet_subnet_id                    = lookup(module.network.vnet_subnets_name_id, "aks")
  os_disk_size_gb                   = 50
  sku_tier                          = "Standard"
  private_cluster_enabled           = false
  enable_auto_scaling               = true
  enable_host_encryption            = false
  log_analytics_workspace_enabled   = true
  agents_min_count                  = 1
  agents_max_count                  = 5
  agents_count                      = null # Please set `agents_count` `null` while `enable_auto_scaling` is `true` to avoid possible `agents_count` changes.
  agents_max_pods                   = 36
  agents_pool_name                  = "system"
  agents_availability_zones         = ["1", "2", "3"]
  agents_type                       = "VirtualMachineScaleSets"
  agents_size                       = var.agents_size
  monitor_metrics                   = {}
  azure_policy_enabled              = true
  microsoft_defender_enabled        = true

  agents_labels = {
    "nodepool" : "defaultnodepool"
  }

  agents_tags = {
    "Agent" : "defaultnodepoolagent"
  }

  network_policy             = "azure"
  net_profile_dns_service_ip = "10.0.0.10"
  net_profile_service_cidr   = "10.0.0.0/16"

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
    metadata     = local.addons_metadata
    addons       = local.addons
  }
  apps = local.argocd_apps
  argocd = {
    namespace = "argocd"
  }
}

resource "azurerm_resource_group" "this" {
  name     = "aks-gitops"
  location = "eastus"
}

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
}
