# Onboarding New Dev Team

and [gitops/workloads](https://github.com/Azure-Samples/aks-platform-engineering/tree/main/gitops/bootstrap/workloads)

    Since there are clusters definied in the workloads folder, CAPZ or Crossplane will also create AKS cluster(s) via the Application definition in ArgoCD.  Clusters were created automatically to show the power of ArgoCD and corresponding CAPZ or Crossplane code, but in a production system a PR would initiate the creation of an environment for a development team.

Optionally for capz only:
- In order to access the workload cluster with a personal SSH key when using the CAPZ control plane option, create an SSH key with the following command. 

    ```bash
    ssh-keygen -m PEM -t rsa -b 4096
    ```

    For more information on creating and using SSH keys, follow [this link](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed).

For crossplane only:
- Update the files cluster-claim.yaml in [dev](./gitops/clusters/crossplane/clusters/my-app-cluster/dev/cluster-claim.yaml) and [stage](./gitops/clusters/crossplane/clusters/my-app-cluster/stage/cluster-claim.yaml) folders for adminUser value as the objectId of the user/group to be designated as the admin for the cluster.


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