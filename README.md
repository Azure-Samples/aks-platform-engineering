## Getting Started

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

Run Terraform:

```bash
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

```kubectl
kubectl --kubeconfig=kubeconfig get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}"
kubectl get svc -n argocd argo-cd-argocd-server
```

In case something goes wrong and you don't find a public IP, connect to the ArgoCD server doing a port forward with kubectl

```kubectl
kubectl port-forward svc/argo-cd-argocd-server -n argocd 8080:443
```

Getting the credentials for the Hub Cluster

```azurecli
az aks get-credentials -n gitops-aks -g aks-gitops
```

Inspecting the Crossplane objects on the Hub Cluster

```kubectl
kubectl get AksClusterClaim -A
kubectl get xaksclusters -A
```

Deploying apps to the workload clusters

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
