# Building a Platform Engineering Environment on Azure Kubernetes Service (AKS)

At its core, platform engineering is about constructing a solid and adaptable groundwork that simplifies and accelerates the development, deployment, and operation of software applications.  The goal is to abstract the complexity inherent in managing infrastructure and operational concerns, enabling dev teams to focus on crafting code that adds direct value. This environment is based on GitOps principles and includes a set of best practices and tools to manage the lifecycle of the applications and the underlying infrastructure. Many platform teams use multiple clusters to separate concerns and provide isolation between different environments, such as development, staging, and production. This guide provides a reference architecture and sample to build a platform engineering environment on Azure Kubernetes Service (AKS).

This sample will illustrate an end-to-end workflow that Platform Engineering and Development teams need to deploy multi-cluster environments on AKS:

- Platform Engineering team deploys a control plane cluster with core infrastructure services and tools to support Day 2 Operations using Terraform and ArgoCD.
- When a new development team is onboarded, the Platform Engineering team provisions new clusters dedicated to that team.  These new clusters will automatically have common required infrastructure tools installed via ArgoCD and have ArgoCD installed automatically.
- The development team optionally installs additional infrastructure tools and customizes the Kubernetes configuration as desired with potential limits enforced by policies from the Platform Engineering team.
- The development team deploys applications using GitOps principles and ArgoCD.

## Architecture

This sample leverages the [GitOps Bridge Pattern](https://github.com/gitops-bridge-dev/gitops-bridge?tab=readme-ov-file).  The following diagram shows the high-level architecture of the solution:  
![Platform Engineering on AKS Architecture Diagram](./images/Architecture%20Diagram.png)

The control plane cluster will be configured with addons via ArgoCD using Terraform and then bootstrapped with tools needed for Day Two operations.  

Choose Crossplane **or** Cluster API provider for Azure (CAPZ) to support deploying and managing clusters and Azure infrastructure for the application teams by changing the Terraform `infrastructure_provider` variable to either `crossplane` or `capz`.  The default is `capz` if no value is specified.  The CAPZ option also automatically installs Azure Service Operator (ASO) so any Azure resource can be provisioned as long as the [CRD pattern](https://azure.github.io/azure-service-operator/guide/crd-management/#automatic-crd-installation-recommended) is specified for desired resources [in the helm values file which installs CAPZ](https://github.com/Azure-Samples/aks-platform-engineering/blob/main/gitops/environments/default/addons/cluster-api-operator/values.yaml#L12).

## Prerequisites

- An active Azure subscription. If you don't have one, create a free Azure account before you begin.
- Azure CLI version 2.60.0 or later installed. To install or upgrade, see Install Azure CLI.
- Terraform v1.8.3 or later [configured for authentication](https://learn.microsoft.com/azure/developer/terraform/authenticate-to-azure?tabs=bash).
- kubectl version 1.28.9 or later installed. To install or upgrade, see Install kubectl.

For choosing the Crossplane option - additional Pre-requisites:

- Create a service principal with the following permissions:
  - Contributor on the subscription

```azurecli
az ad sp create-for-rbac --name "<service-principal-name>" --role Contributor --scopes /subscriptions/<subscription-id>
```

## Getting Started

### Provisioning the Control Plane Cluster

Until the repo is public you need a ssh deploy key for ArgoCD to clone this repo.
Obtain the key from the team and place it in `terraform/private_ssh_deploy_key`

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

Getting the credentials for the Control Plane Cluster

```shell
export KUBECONFIG=<your_path_to_this_repo>/aks-platform-engineering/terraform/kubeconfig
```

```kubectl
kubectl get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}"
kubectl get svc -n argocd argo-cd-argocd-server
```

The username for ArgoCD is `admin`.

In case something goes wrong and you don't find a public IP, connect to the ArgoCD server doing a port forward with kubectl

```kubectl
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443
```
