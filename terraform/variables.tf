variable "resource_group_name" {
  description = "Specifies the name of the resource group."
  default     = "aks-gitops"
  type        = string
}

variable "location" {
  description = "Specifies the the location for the Azure resources."
  type    = string
  default = "eastus"
}

variable "agents_size" {
  description = "Specifies the default virtual machine size for the Kubernetes agents"
  default     = "Standard_D8s_v3"
  type        = string
}

variable "kubernetes_version" {
  description = "Specifies which Kubernetes release to use. The default used is the latest Kubernetes version available in the location."
  type        = string
  default     = null
}

variable "addons" {
  description = "Specifies the Kubernetes addons to install."
  type        = any
  default = {
    enable_argocd                            = true # installs argocd
    enable_ingress_nginx                     = true # installs ingress-nginx
    enable_crossplane_kubernetes_provider    = true # installs kubernetes provider
    enable_crossplane_helm_provider          = true # installs helm provider
    enable_crossplane                        = true # installs crossplane core
    enable_azure_crossplane_provider         = true # installs azure contrib provider
    enable_azure_crossplane_upbound_provider = true # installs azure upbound provider
  }
}

# Addons Git
variable "gitops_addons_org" {
  description = "Specifies the Git repository org/user contains for addons."
  type        = string
  default     = "https://github.com/zioproto"
}
variable "gitops_addons_repo" {
  description = "Specifies the Git repository contains for addons."
  type        = string
  default     = "aks-gitops-bridge-sandbox"
}
variable "gitops_addons_revision" {
  description = "Specifies the Git repository revision/branch/ref for addons."
  type        = string
  default     = "main"
}
variable "gitops_addons_basepath" {
  description = "Specifies the Git repository base path for addons."
  type        = string
  default     = "gitops/" # ending slash is important!
}
variable "gitops_addons_path" {
  description = "Specifies the Git repository path for addons."
  type        = string
  default     = "bootstrap/control-plane/addons"
}

# Workloads Git
variable "gitops_workload_org" {
  description = "Git repository org/user contains for workload."
  type        = string
  default     = "https://github.com/zioproto"
}
variable "gitops_workload_repo" {
  description = "Specifies the Git repository contains for workload."
  type        = string
  default     = "aks-gitops-bridge-sandbox"
}
variable "gitops_workload_revision" {
  description = "Specifies the Git repository revision/branch/ref for workload."
  type        = string
  default     = "main"
}
variable "gitops_workload_basepath" {
  description = "Specifies the Git repository base path for workload."
  type        = string
  default     = "gitops/"
}
variable "gitops_workload_path" {
  description = "Specifies the Git repository path for workload."
  type        = string
  default     = "apps"
}

variable "tags" {
  description = "Specifies tags for all the resources."
  default     = {
    createdWith = "Terraform"
    pattern     = "GitOpsBridge"
  }
}

variable "role_based_access_control_enabled" {
  description = "Is Role Based Access Control Enabled? Changing this forces a new resource to be created."
  type        = bool
  default     = true
}

variable "rbac_aad" {
  description = "Is Role Based Access Control based on Azure AD enabled?"
  type        = bool
  default     = false
}

variable "prefix" {
  description = "Specifies the prefix for the AKS cluster"
  type        = string
  default     = "gitops"
}

variable "network_plugin" {
  description = "Specifies the network plugin of the AKS cluster"
  default     = "azure"
  type        = string
}

variable "os_disk_size_gb" {
  description = "Specifies the OS disk size"
  type        = number
  default     = 50
}

variable "sku_tier" {
  description = "Specifies the SKU Tier that should be used for this AKS Cluster."
  type        = string
  default     = "Standard"
}

variable "private_cluster_enabled" {
  description = "Specifies wether the AKS cluster be private or not."
  default     = false
  type        = bool
}

variable "enable_auto_scaling" {
  description = "Specifies whether to enable auto-scaler. Defaults to false."
  type          = bool
  default       = true
}

variable "enable_host_encryption" {
  description = "Specifies whether the nodes in this Node Pool have host encryption enabled. Defaults to false."
  type          = bool
  default       = false
} 

variable "log_analytics_workspace_enabled" {
  description = "Specifies whether Log Analytics is enabled"
  type          = bool
  default       = true
} 

variable "agents_min_count" {
  description = "Specifies the minimum number of nodes which should exist within this Node Pool. Valid values are between 0 and 1000 and must be less than or equal to max_count."
  type          = number
  default       = 1
}

variable "agents_max_count" {
  description = "Specifies the maximum number of nodes which should exist within this Node Pool. Valid values are between 0 and 1000 and must be greater than or equal to min_count."
  type          = number
  default       = 5
}

variable "agents_max_pods" {
  description = "Specifies the maximum number of pods that can run on each agent. Changing this forces a new resource to be created."
  type          = number
  default       = 50
}

variable "azure_policy_enabled" {
  description = "Should the Azure Policy Add-On be enabled? For more details please visit Understand Azure Policy for Azure Kubernetes Service"
  type        = bool
  default     = true
}

variable "network_policy" {
  description = "Specifies the type of network policy to use for Kubernetes."
  type        = string
  default     = "azure"
}

variable "microsoft_defender_enabled" {
  description = "Should Microsoft Defender for Containers be enabled? For more details please visit Microsoft Defender for Containers"
  type        = bool
  default     = true
}

variable "net_profile_dns_service_ip" {
  description = "Specifies the DNS service IP"
  default     = "10.0.0.10"
  type        = string
}

variable "net_profile_service_cidr" {
  description = "Specifies the service CIDR"
  default     = "10.0.0.0/16"
  type        = string
}

variable "crossplane_application_name" {
  description = "Specifies the name of the Crossplane Microsoft Entra ID registered application."
  default     = "crossplane"
  type        = string
}