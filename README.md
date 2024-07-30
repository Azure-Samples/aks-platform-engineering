# Building a Platform Engineering Environment on Azure Kubernetes Service (AKS)

At its core, platform engineering is about constructing a solid and adaptable groundwork that simplifies and accelerates the development, deployment, and operation of software applications.  The goal is to abstract the complexity inherent in managing infrastructure and operational concerns, enabling dev teams to focus on crafting code that adds direct value. This environment is based on GitOps principles and includes a set of best practices and tools to manage the lifecycle of the applications and the underlying infrastructure. Many platform teams use multiple clusters to separate concerns and provide isolation between different environments, such as development, staging, and production. This guide provides a reference architecture and sample to build a platform engineering environment on Azure Kubernetes Service (AKS).

This sample will illustrate an end-to-end workflow that Platform Engineering and Development teams need to deploy multi-cluster environments on AKS:

- Platform Engineering team deploys a control plane cluster with core infrastructure services and tools to support Day 2 Operations using Terraform and ArgoCD.
- When a new development team is on boarded, the Platform Engineering team provisions new clusters dedicated to that team.  These new clusters will automatically have common required infrastructure tools installed via ArgoCD and have ArgoCD installed automatically.
- The development team optionally installs additional infrastructure tools and customizes the Kubernetes configuration as desired with potential limits enforced by policies from the Platform Engineering team.
- The development team deploys applications using GitOps principles and ArgoCD.

## Architecture

This sample leverages the [GitOps Bridge Pattern](https://github.com/gitops-bridge-dev/gitops-bridge?tab=readme-ov-file).  The following diagram shows the high-level architecture of the solution:  
![Platform Engineering on AKS Architecture Diagram](./images/AKS-platform-engineering-architecture.png)

The control plane cluster will be configured with addons via ArgoCD using Terraform and then bootstrapped with tools needed for Day Two operations.  

Choose Crossplane **or** Cluster API provider for Azure (CAPZ) to support deploying and managing clusters and Azure infrastructure for the application teams by changing the Terraform `infrastructure_provider` variable to either `crossplane` or `capz`.  [See this document](./docs/capz-or-crossplane.md) for further information on the comparison.  The default is `capz` if no value is specified.

## Prerequisites

- An active Azure subscription. If you don't have one, create a free Azure account before you begin.
- Azure CLI version 2.60.0 or later installed. To install or upgrade, see Install Azure CLI.
- Terraform v1.8.3 or later [configured for authentication](https://learn.microsoft.com/azure/developer/terraform/authenticate-to-azure?tabs=bash) where the user account has permissions to create resource groups and user managed identities on the subscription to setup workload identity for the AKS cluster (capz option).
- kubectl version 1.28.9 or later installed. To install or upgrade, see Install kubectl.

## Getting Started

### Provisioning the Control Plane Cluster

- Fork the repo
- If the repo is or desired to be private, ArgoCD will need a ssh deploy key to access this repo. Create a [read-only deploy ssh key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#deploy-keys) on the fork and place the corresponding private key named `private_ssh_deploy_key` in the `terraform` directory.  Additionally, change the `gitops_addons_org` variable to use the `git@github.com:Azure-Samples` format versus `https://`.

Run Terraform:

```bash
cd terraform
terraform init -upgrade
```

Choose to apply capz or crossplane.

> [!Important] 
> Change `azure-samples` to your fork organization or GitHub user name in the commands below.

Alternatively, consider changing the example `tvars` file to match your desired configuration versus using the `-var` switches below.

```bash
# For capz control plane
terraform apply -var gitops_addons_org=https://github.com/azure-samples --auto-approve

# For crossplane control plane
terraform apply -var gitops_addons_org=https://github.com/azure-samples \
                -var infrastructure_provider=crossplane --auto-approve
```

> Note: You can ignore the warnings related to deprecated attributes and invalid kubeconfig path.

Terraform completed installing the AKS cluster, installing ArgoCD, and configuring ArgoCD to install applications under the `gitops/bootstrap/control-plane/addons` directory from the git repo.

### Accessing the Control Plane Cluster and ArgoCD UI

Getting the credentials for the Control Plane Cluster

```shell
export KUBECONFIG=<your_path_to_this_repo>/aks-platform-engineering/terraform/kubeconfig
echo $KUBECONFIG
```

```shell
# Get the initial admin password and the IP address of the ArgoCD web interface.
kubectl get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}"
kubectl get svc -n argocd argo-cd-argocd-server
```

It may take a few minutes for the LoadBalancer to create a public IP for the ArgoCD UI after the Terraform apply. In case something goes wrong and you don't find a public IP, connect to the ArgoCD server doing a port forward with kubectl and access the UI on https://localhost:8080.

```kubectl
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443
```

The username for the ArgoCD UI login is `admin`.

### Install and configure CAPZ using Cluster-API operator

The crossplane option will automatically install via ArgoCD when using the `var infrastructure_provider=crossplane`, but the CAPZ option will need to be installed manually.  Cert-manager was automatically installed via ArgoCD which is an install pre-requisite. Workload identity was also created and attached to the AKS management cluster.

First verify that certificate manager is installed and pods are ready in the `cert-manager` namespace.

```shell
kubectl get pods -n cert-manager
```

```shell
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-cainjector-57fd464d97-l89hs   1/1     Running   0          84s
cert-manager-d548d744-ghmf9                1/1     Running   0          84s
cert-manager-webhook-8656b957f-4rhr6       1/1     Running   0          84s
```

The following steps will install CAPZ via the Cluster-API operator which also includes Azure Service Operator (ASO) to the management cluster.

```shell
helm repo add capi-operator https://kubernetes-sigs.github.io/cluster-api-operator
helm repo update
helm install capi-operator capi-operator/cluster-api-operator --create-namespace -n capi-operator-system \
--set infrastructure="azure:v1.16.0" \
--set addon="helm:v0.2.4" \
--set core="cluster-api:v1.7.4" \
--set manager.featureGates.core.MachinePool="true" \
--set manager.featureGates.azure.MachinePool="true" \
--wait --timeout 90s
```
This will take some time to install and can be verified it is complete by seeing two ready pods in the `azure-infrastructure-system` namespace. 

```shell
kubectl get pods -n azure-infrastructure-system
```

```shell
NAME                                                      READY   STATUS    RESTARTS       AGE
azureserviceoperator-controller-manager-d9d69f497-h5cdm   1/1     Running   1 (115s ago)   2m24s
capz-controller-manager-ff97799dd-8l5n2                   1/1     Running   0              2m23s
```
Now apply the credentials for CAPZ to be able to create resources using the Workload Identity created by Terraform.

Add in the `clientID:` and `tenantID:` values from the `terraform apply` matching output values to the `gitops/hooks/identity/identity.yaml` file. Feel free to run `terraform apply` again if needed to get these output values.  Then apply the identity to the cluster.

```shell
kubectl apply -f ../gitops/hooks/identity/identity.yaml
```

### Summary

1. Terraform created an AKS control plane / management cluster and downloaded the kubeconfig file in the `terraform` directory.
1. Terraform installed ArgoCD via the Terraform Kubernetes provider to that cluster
1. Terraform did a `kubectl apply` an ArgoCD ApplicationSet to the cluster which syncs the bootstrap folder [gitops/bootstrap/control-plane/addons](https://github.com/Azure-Samples/aks-platform-engineering/tree/main/gitops/bootstrap/control-plane/addons). That ApplicationSet utilizes the [ArgoCD App of Apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/#app-of-apps-pattern) and ArgoCD applies all of the applications under that folder in git which match the [labels specified in Terraform](https://github.com/Azure-Samples/aks-platform-engineering/blob/main/terraform/main.tf#L20-L38).

## Next Steps

Learn how to define your own cluster, infrastructure, and hand off to the development team the access to the AKS cluster and ArgoCD deployment UI in [this article](./docs/Onboard-New-Dev-Team.md).

## Trademarks

Trademarks This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow Microsoft’s Trademark & Brand Guidelines. Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party’s policies.