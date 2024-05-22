# Building a Platform Engineering Environment on Azure Kubernetes Service (AKS)

At its core, platform engineering is about constructing a solid and adaptable groundwork that simplifies and accelerates the development, deployment, and operation of software applications.  The goal is to abstract the complexity inherent in managing infrastructure and operational concerns, enabling dev teams to focus on crafting code that adds direct value. This environment should be based on GitOps principles and include a set of best practices and tools to manage the lifecycle of the applications and the underlying infrastructure. Many platform teams use multiple clusters to separate concerns and provide isolation between different environments, such as development, staging, and production as well as between applications. This guide provides a reference architecture and sample to build a platform engineering environment on Azure Kubernetes Service (AKS).

This sample will illustrate the end-to-end workflow that Platform Engineering and Development teams need to deploy multi-cluster environments on AKS:

- Platform Engineering team deploys a control plane cluster with core infrastructure services and tools to support Day 2 Operations using Terraform and ArgoCD.
- When a new development team is onboarded, the Platform Engineering team provisions new clusters dedicated to that team.
- The development team installs additional tools and customizes Kubernetes configuration as desired.
- The development team deploys applications using GitOps principles and ArgoCD.

## Architecture

This sample leverages the [GitOps Bridge Pattern](https://github.com/gitops-bridge-dev/gitops-bridge?tab=readme-ov-file).  The following diagram shows the high-level architecture of the solution:  
![Platform Engineering on AKS Architecture Diagram](./images/Architecture%20Diagram.png)

The control plane cluster will be configured with addons via ArgoCD using Terraform and then bootstrapped with tools needed for Day Two operations.  Crossplane **or** Cluster API addons will be configured to support deploying and managing clusters for the application teams.

## Prerequisites

- An active Azure subscription. If you don't have one, create a free Azure account before you begin.
- Azure CLI version 2.49.0 or later installed. To install or upgrade, see Install Azure CLI.
- Terraform v1.5.2 or later.
- kubectl version 1.18.0 or later installed. To install or upgrade, see Install kubectl.

## Getting Started

### Provisioning the Control Plane Cluster

Until the repo is private you need a ssh deploy key for ArgoCD to clone this repo.
Obtain the key from the team and place it in `terraform/private_ssh_deploy_key`

Pre-requisites:

- Create a service principal with the following permissions:
  - Contributor on the subscription

```azurecli
az ad sp create-for-rbac --name "<service-principal-name>" --role Contributor --scopes /subscriptions/<subscription-id>
```

- Fork the repo
- Update the files cluster-claim.yaml in [dev](./gitops/clusters/crossplane/clusters/my-app-cluster/dev/cluster-claim.yaml) and [stage](./gitops/clusters/crossplane/clusters/my-app-cluster/stage/cluster-claim.yaml) folders for adminUser value as the objectId of the user/group to be designated as the admin for the cluster.
- In order to access the workload cluster with a personal SSH key when using the CAPZ control plane option, create an SSH key with the following command. For more information on creating and using SSH keys, follow [this link](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed).

```bash
ssh-keygen -m PEM -t rsa -b 4096
```

Run Terraform:

```bash
cd terraform
terraform init -upgrade
# the gitops_addons_org needs to be in the git format to use the SSH key until the repo is private
terraform apply -var infrastructure_provider=crossplane \
                -var gitops_addons_org=git@github.com:Azure-Samples \
                -var gitops_workload_org=git@github.com:Azure-Samples \
                -var service_principal_client_id=xxxxxxxx \
                -var service_principal_client_secret=xxxxxxxxxx \
                -var git_public_ssh_key="$(cat ~/.ssh/id_rsa.pub)"
```

**Note:** Omit the `git_public_ssh_key` variable if SSH key access is not required.

Get the initial admin password and the IP address of the ArgoCD web interface.
(Wait a few minutes for the LoadBalancer to be created after the Terraform apply)

```kubectl
kubectl --kubeconfig=kubeconfig get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}"
kubectl get svc -n argocd argo-cd-argocd-server
```

In case something goes wrong and you don't find a public IP, connect to the ArgoCD server doing a port forward with kubectl

```kubectl
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443
```

Getting the credentials for the Control Plane Cluster

```azurecli
az aks get-credentials -n gitops-aks -g aks-gitops
```

## Onboarding New Application Team

```kubectl
kubectl get AksClusterClaim -A
kubectl get xaksclusters -A
```

### Deploying apps to the workload clusters

```azurecli

az aks get-credentials -n my-app-cluster-dev -g my-app-cluster-dev
```

Deploy a sample app using an ArgoCD Application

```kubectl
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
name: app-of-apps
namespace: argocd
spec:
project: default
source:    
    repoURL: https://github.com/Azure-Samples/aks-store-demo.git    
    targetRevision: HEAD
    path: kustomize/overlays/dev             
syncPolicy:
    automated: {}
destination:
    namespace: argocd
    server: https://kubernetes.default.svc
EOF
```
