# Onboarding New Dev Team

Now that the management cluster is up and running, the next step is to onboard a new development team. This involves creating new workload cluster(s) and necessary infrastructure for the team to deploy their applications.

## Setup a new Team infrastructure using ArgoCD

There is example code to create new AKS clusters using CAPZ and Crossplane in the `/gitops/clusters/` folder, but these clusters are not being created yet since there is no ArgoCD application added on the management cluster to sync to this directory.

We will add the application to sync and create the clusters below, but first modify the values for this code before doing the commit to git to create the team clusters:

For crossplane only:
- Update the files cluster-claim.yaml in [dev](./gitops/clusters/crossplane/clusters/my-app-cluster/dev/cluster-claim.yaml) and [stage](./gitops/clusters/crossplane/clusters/my-app-cluster/stage/cluster-claim.yaml) folders for adminUser value as the objectId of the user/group to be designated as the admin for the cluster.

Optional for capz only:
- In order to access the workload cluster with a personal SSH key when using the CAPZ control plane option, create an SSH key with the following command. For more information on creating and using SSH keys, follow [this link](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed).

```bash
ssh-keygen -m PEM -t rsa -b 4096
```

After these changes, commit the changes to the git repo on your fork.

Next, create an ArgoCD application to sync the new team clusters by doing a `kubectl apply -f`` with the following code:

```
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: clusters
  namespace: argocd
spec:
  syncPolicy:
    preserveResourcesOnDeletion: true
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: control-plane
  template:
    metadata:
      name: clusters
    spec:
      project: default
      source:
        repoURL: '{{metadata.annotations.addons_repo_url}}'
        targetRevision: '{{metadata.annotations.addons_repo_revision}}'
        path: 'gitops/clusters/{{metadata.annotations.infrastructure_provider}}'
      destination:
        name: '{{name}}'
        namespace: workload
      syncPolicy:
        retry:
          limit: 10
        automated: {}
        syncOptions:
          - CreateNamespace=true
```

The application will show up in the ArgoCD console and start provisioning the infrastructure in the `gitops/clusters/` folder.

## Connect to existing deployed workload cluster

To connect to the existing AKS clusters which have been deployed above do the following:

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
