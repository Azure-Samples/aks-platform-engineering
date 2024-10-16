variable "resource_group_name" {
  description = "Specifies the name of the resource group."
  default     = "aks-gitops"
  type        = string
}

variable "location" {
  description = "Specifies the the location for the Azure resources."
  type        = string
  default     = "eastus2"
}

variable "agents_size" {
  description = "Specifies the default virtual machine size for the Kubernetes agents"
  default     = "Standard_D2s_v3"
  type        = string
}

variable "kubernetes_version" {
  description = "Specifies which Kubernetes release to use. The default used is the latest Kubernetes version available in the location."
  type        = string
  default     = null
}

variable "infrastructure_provider" {
  description = "Specific the choice of infrastructure provider. crossplane or capz"
  type        = string
  default     = "capz"
}

variable "addons" {
  description = "Specifies the Kubernetes addons to install on the hub cluster."
  type        = any
  default = {
    enable_argocd                            = true # installs argocd
  }
}

variable "addons_versions" {
  description = "Specifies the Kubernetes addons to install on the hub cluster."
  type        = list (object({
    argocd_chart_version = string
    argo_rollouts_chart_version = string
    kargo_chart_version = string
  }))
  default = [{
    argocd_chart_version                     = "7.6.10" # https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/Chart.yaml
    argo_rollouts_chart_version              = "2.37.7" # https://github.com/argoproj/argo-helm/blob/main/charts/argo-rollouts/Chart.yaml
    kargo_chart_version                      = "0.9.1" # https://github.com/akuity/kargo/releases
  }]
}

variable "git_private_ssh_key" {
  description = "Filepath to the private SSH key for git access"
  type        = string
  default     = "./private_ssh_deploy_key"
}

variable "git_public_ssh_key" {
  description = "A custom ssh key to control access to the AKS workload cluster(s). This should a string containing the key and not a filepath to the key."
  type        = string
  default     = ""
}

# Addons Git
variable "gitops_addons_org" {
  description = "Specifies the Git repository org/user contains for addons."
  type        = string
  default     = "https://github.com/azure-samples"
}
variable "gitops_addons_repo" {
  description = "Specifies the Git repository contains for addons."
  type        = string
  default     = "aks-platform-engineering"
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
variable "tags" {
  description = "Specifies tags for all the resources."
  default = {
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

variable "os_sku" {
  type        = string
  default     = "AzureLinux"
  description = "(Optional) Specifies the OS SKU used by the agent pool. Possible values are AzureLinux, Ubuntu, Windows2019 and Windows2022. If not specified, the default is Ubuntu if OSType=Linux or Windows2019 if OSType=Windows. And the default Windows OSSKU will be changed to Windows2022 after Windows2019 is deprecated. Changing this from AzureLinux or Ubuntu to AzureLinux or Ubuntu will not replace the resource, otherwise temporary_name_for_rotation must be specified when attempting a change."
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
  type        = bool
  default     = true
}

variable "enable_host_encryption" {
  description = "Specifies whether the nodes in this Node Pool have host encryption enabled. Defaults to false."
  type        = bool
  default     = false
}

variable "log_analytics_workspace_enabled" {
  description = "Specifies whether Log Analytics is enabled"
  type        = bool
  default     = false
}

variable "agents_min_count" {
  description = "Specifies the minimum number of nodes which should exist within this Node Pool. Valid values are between 0 and 1000 and must be less than or equal to max_count."
  type        = number
  default     = 1
}

variable "agents_max_count" {
  description = "Specifies the maximum number of nodes which should exist within this Node Pool. Valid values are between 0 and 1000 and must be greater than or equal to min_count."
  type        = number
  default     = 5
}

variable "agents_max_pods" {
  description = "Specifies the maximum number of pods that can run on each agent. Changing this forces a new resource to be created."
  type        = number
  default     = 50
}

variable "azure_policy_enabled" {
  description = "Should the Azure Policy Add-On be enabled? For more details please visit Understand Azure Policy for Azure Kubernetes Service"
  type        = bool
  default     = false
}

variable "network_policy" {
  description = "Specifies the type of network policy to use for Kubernetes."
  type        = string
  default     = "azure"
}

variable "microsoft_defender_enabled" {
  description = "Should Microsoft Defender for Containers be enabled? For more details please visit Microsoft Defender for Containers"
  type        = bool
  default     = false
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
