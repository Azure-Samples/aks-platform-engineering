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
