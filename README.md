# Building a Platform Engineering Environment on Azure Kubernetes Service (AKS)

Customers are looking to build a platform engineering environment on Azure Kubernetes Service (AKS) to enable their development teams to deploy and manage applications in a consistent and secure manner. This environment should be based on GitOps principles and include a set of best practices and tools to manage the lifecycle of the applications and the underlying infrastructure. This guide provides a reference architecture and sample to build a platform engineering environment on AKS.

This sample demonstrates how to deploy an multi-cluster AKS environment that supports both platform and application development teams leveraging the GitOps Bridge Pattern.  The management cluster will be configured with addons via ArgoCD using Terraform and then bootstrapped with tools needed for Day Two operations.  Crossplane or Cluster API addons to will be configured to support deploying and managing clusters for the application teams.

## What is GitOps?

## GitOps Bridge Pattern

## Argo CD

## Cluster API

## Crossplane

## Prerequisites

- An active Azure subscription. If you don't have one, create a free Azure account before you begin.
- Azure CLI version 2.49.0 or later installed. To install or upgrade, see Install Azure CLI.
- Terraform v1.5.2 or later.
- kubectl version 1.18.0 or later installed. To install or upgrade, see Install kubectl.

## Solution Overview

The following diagram shows the high-level architecture of the solution leveraging GitOps Bridge Pattern.  
[architecture diagram]

## Walkthrough

## Getting Started

Until the repo is private you need a ssh deploy key for ArgoCD to clone this repo.
Obtain the key from the team and place it in `terraform/private_ssh_deploy_key`

Run Terraform:

```
cd terraform
terraform init -upgrade
# the gitops_addons_org needs to be in the git format to use the SSH key until the repo is private
terraform apply -var infrastructure_provider=crossplane \
                -var gitops_addons_org=git@github.com:Azure-Samples \
                -var gitops_workload_org=git@github.com:Azure-Samples \
                -var service_principal_client_id=xxxxxxxx \
                -var service_principal_client_secret=xxxxxxxxxx
```

Get the initial admin password and the IP address of the ArgoCD web interface.
(Wait a few minutes for the LoadBalancer to be created after the Terraform apply)

```
kubectl --kubeconfig=kubeconfig get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}"
kubectl get svc -n argocd argo-cd-argocd-server
```

## Onboarding Applications Workloads

## References