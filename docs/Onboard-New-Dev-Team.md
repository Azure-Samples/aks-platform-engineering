# Onboarding New Dev Team

Now that the management cluster is up and running, the next step is to onboard a new development team. This involves creating new workload cluster(s) and necessary infrastructure for the team to deploy their applications.

## Setup a new Team infrastructure using ArgoCD

There is example code to create new AKS clusters using CAPZ and Crossplane in the `/gitops/clusters/` folder.  Add a new ArgoCD application to the management cluster to make ArgoCD automatically provision these clusters.

First modify the values for this code before doing the commit to git to create the team clusters:

For crossplane only:
- Update the files cluster-claim.yaml in [dev](./gitops/clusters/crossplane/clusters/my-app-cluster/dev/cluster-claim.yaml) and [stage](./gitops/clusters/crossplane/clusters/my-app-cluster/stage/cluster-claim.yaml) folders for adminUser value as the objectId of the user/group to be designated as the admin for the cluster.

Optional for capz only:
- In order to access the workload cluster with a personal SSH key when using the CAPZ control plane option, create an SSH key with the following command. For more information on creating and using SSH keys, follow [this link](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed).

```bash
ssh-keygen -m PEM -t rsa -b 4096
```



## Connect to existing deployed workload cluster

To connect to the existing AKS clusters which have already been deployed automatically with the initial terraform apply, do the following:

With Crossplane:

```bash
az aks get-credentials -n my-app-cluster-dev -g my-app-cluster-dev
```

With CAPZ:

```bash
az aks get-credentials -n aks0 -g aks0
```

## Dev team deploy application using ArgoCD

TODO: insert instructions for developers to do a PR to repo and the aks store demo application automatically get deployed to cluster

TODO: Below is code to create an ArgoCD application for the new team, which needs to be put into git operation PR.

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
