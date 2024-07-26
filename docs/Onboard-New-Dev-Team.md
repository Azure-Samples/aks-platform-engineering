# Onboarding New Dev Team

Now that the management cluster is up and running, the next step is to onboard a new development team. This involves creating new workload cluster(s) and necessary infrastructure for the team to deploy their applications.

## Setup a new Team infrastructure using ArgoCD

There is example code to create new AKS clusters using CAPZ and Crossplane in the `/gitops/clusters/` folder, but these clusters are not being created yet since there is no ArgoCD application added on the management cluster to sync to this directory.

We will add the application to sync and create the clusters below, but first modify the values for this code before doing the commit to git to create the team clusters:

For crossplane only - update these files:
  - cluster-claim.yaml in [base](./gitops/clusters/crossplane/clusters/my-app-cluster/base/cluster-claim.yaml) - - change line 31 adminGroupObjectIds value as the objectId of the user/group to be designated as the admin for the clusters.
  - cluster-claim.yaml in [dev](./gitops/clusters/crossplane/clusters/my-app-cluster/dev/cluster-claim.yaml) - change line 13 adminUser value as the objectId of the user to be designated as the admin user for the cluster.
  - cluster-claim.yaml in [stage](./gitops/clusters/crossplane/clusters/my-app-cluster/stage/cluster-claim.yaml) - change line 13 adminUser value as the objectId of the user to be designated as the admin user for the cluster.

Optional for CAPZ only:
- In order to access the workload cluster with a personal SSH key when using the CAPZ control plane option, create an SSH key with the following command. For more information on creating and using SSH keys, follow [this link](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed).

```bash
ssh-keygen -m PEM -t rsa -b 4096
```

Update the  `sshPublicKey` value in the `gitops/clusters/capz/aks-appset.yaml` file.

After these changes, commit the changes to the git repo on your fork.

Next, create an ArgoCD application to sync the new team clusters by running this command against the management cluster:

```
kubectl apply -f ../gitops/clusters/clusters-argo-applicationset.yaml
```

The application will show up in the ArgoCD console and start provisioning the infrastructure in the `gitops/clusters/<capz/crossplane>` folder.  The metadata in that file is already present on the ArgoCD cluster from the initial `terraform apply` and can be seen in the management ArgoCD UI - under `Settings - Clusters - gitops-aks` cluster.  The team cluster creation will take a few minutes.

## Connect to existing deployed workload cluster

To connect to the existing AKS clusters which have been deployed above do the following:

With Crossplane:

```bash
az aks get-credentials -n my-app-cluster-dev -g my-app-cluster-dev
kubelogin convert-kubeconfig -l azurecli
```

With CAPZ:

```bash
az aks get-credentials -n aks0 -g aks0
```

## Dev team deploy application using ArgoCD

The existing clusters already installed ArgoCD and the required platform engineering requirements from the ArgoCD application which again utilized the app of apps pattern to install everything in the `gitops/apps/infra` folder.

The new dev team would like to install their application so they will create a new ArgoCD application which synchronizes to the folder in their own repository which contains the Kubernetes deployment manifests. The repoURL could be any git repository, but assume this public sample app repository is the developer team's repo to make things easier for demo purposes. Execute a `kubectl apply -f` with the following code while connected to the team cluster:

```kubectl
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aks-store-demo
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

The AKS store demo application was installed into the `pets` namespace and webpage can be [visited by following instructions here](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli#test-the-application). Be sure to visit the IP address using `http` and not `https`.

The development team can also view the status of the applications in the ArgoCD console installed on the team cluster.

```shell
# Get the initial admin password and the IP address of the ArgoCD web interface.
kubectl get secrets argocd-initial-admin-secret -n argocd --template="{{index .data.password | base64decode}}"
kubectl get svc -n argocd argo-cd-argocd-server
```
