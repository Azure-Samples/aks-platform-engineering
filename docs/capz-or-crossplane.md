# Choose your control plane provider

There are two Kubernetes control plane providers to choose from: capz or crossplane.  The purpose of this document is to help you decide which control plane provider might be best for your organization to use.

## Cluster API Provider for Azure (CAPZ) and Azure Service Operator (ASO)

CAPZ is the Azure provider for Cluster API which has more than [30 different providers](https://cluster-api.sigs.k8s.io/reference/providers) that provision managed and self-managed Kubernetes clusters in a conformant way.  Cluster API by itself only provisions Kubernetes clusters.  However, the CAPZ project has taken a dependency on ASO which gets installed automatically along with CAPZ.  ASO is a Kubernetes operator that provides a way to provision and manage [any Azure resources](https://azure.github.io/azure-service-operator/reference/) using Kubernetes Custom Resource Definitions (CRDs).  To specify additional ASO Azure resources [beyond what CAPZ automatically enables](https://github.com/kubernetes-sigs/cluster-api-provider-azure/blob/main/Makefile#L169) to be able to be provisioned, simply [specify the CRD pattern during installation](https://capz.sigs.k8s.io/topics/aso.html?highlight=ASO#using-aso-for-non-capz-resources).

Both CAPZ and ASO are officially staffed and supported open source projects by Microsoft which have regular releases, community calls, and Kubernetes slack channel support.  ASO has an [automation process which generates Kubernetes CRDs directly from the Azure APIs](https://azure.github.io/azure-service-operator/contributing/generator-overview/).  This is advantageous because it allows 100% API coverage directly from the source of truth.

One other unique advantage of the CAPZ and ASO stack is there is an option to [import existing production AKS clusters](https://capz.sigs.k8s.io/managed/adopting-clusters) into the control plane.  This is useful for organizations that have existing AKS clusters and want to start managing them in a GitOps platform engineering centric way like this repository demonstrates.

## Crossplane

Crossplane is a CNCF project that provides a Kubernetes control plane to manage infrastructure resources across multiple cloud providers in a consistent way using Kubernetes Custom Resource Definitions (CRDs).  The [Crossplane project](https://github.com/crossplane/crossplane) and [Azure provider for Crossplane](https://github.com/crossplane-contrib/provider-upjet-azure) is open source, but supported primarily by the startup [Upbound](https://www.upbound.io/) which has a paid offering based on top of Crossplane and the general community.  The Azure provider for Crossplane is written on top of the [Terraform go SDK for Azure](https://github.com/crossplane-contrib/provider-upjet-azure/blob/35c73f51f9b32091717de22c79a7928c2802f3c6/go.mod#L18), so there is a layer of abstraction between the Azure API and the CRDs.

The advantage of Crossplane is that it is cloud agnostic and can manage many resources across multiple cloud providers with a single, relatively consistent infrastructure as code YAML structure. There are also additional benefits from using the paid offering from Upbound.

## Comparison Summary

If you want to run multi-cloud and highly value the ability to manage multiple non-Kubernetes-cluster cloud provider resources in a consistent way, and you don't mind going to the general open source community and/or Upbound for support, then Crossplane could be a good choice.

If you are not multi-cloud or don't care about inconsistency in non-Kubernetes-cluster resources YAML code definitions, then CAPZ and ASO is a good logical choice.  It is officially supported by Microsoft and has a direct mapping to the Azure APIs.  This means you can get 100% API coverage and have a direct line to the source of truth for Azure resources.  Additionally, if you have existing AKS clusters, you can import them into the control plane, enabling the GitOps platform engineering pattern as demonstrated here.
