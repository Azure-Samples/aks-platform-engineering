# Onboarding New Dev Team

## Connect to existing deployed workload cluster

To connect to the existing AKS clusters which have already been deployed automatically with the initial terraform apply, do the following:

With Crossplane:

```kubectl
kubectl get AksClusterClaim -A
kubectl get xaksclusters -A
```
or
```bash
az aks get-credentials -n my-app-cluster-dev -g my-app-cluster-dev
```

With CAPZ:

```bash
az aks get-credentials -n aks0 -g aks0
```

### Manually deploying apps to the workload clusters

Deploy a sample app using an ArgoCD application just to see this application manually.

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

## Setup a new Team infrastructure using ArgoCD

<insert instructions on provisioning core infrastructure needed for dev team.  e.g. keyvault, aks, database, etc>

## Dev team deploy application using ArgoCD

<insert instructions for developers to do a PR to repo and the aks store demo application automatically get deployed to cluster>