# Backstage

## Overview

Backstage is an open platform for building developer portals. It was created by Spotify to streamline their development processes and has since been open-sourced. Backstage allows you to manage all your infrastructure, services, and tools in one place, providing a unified developer experience.

## Features

- **Service Catalog**: Organize and manage all your services.
- **Software Templates**: Standardize and automate the creation of new projects.
- **TechDocs**: Centralize your documentation.
- **Plugins**: Extend Backstage with a wide range of plugins.

## Context in This Project

In this project, Backstage is used to provide a unified developer portal that integrates various tools and services. It helps in managing the infrastructure and services more efficiently. The project leverages Backstage to:

- **Centralize Documentation**: Using TechDocs to keep all documentation in one place.
- **Manage Services**: Using the Service Catalog to organize and manage microservices.
- **Automate Workflows**: Using Software Templates to standardize project creation.

## Optional - Building Backstage Image
This repo uses a hosted backstage image with entra auth enabled, automatically onboarding users into your backstage user list. It also has an example software catalog template to demo creating the resources required for argo to create and bootstrap a cluster named by the user. If you want to test Backstage please continue to getting started. 

If you want to make changes to this image such as adding a different domain or new software catalogs you will need to make your changes, build your own image and change the deployment manifest to reference the image you have created. The source code for Backstage is found in the root Backstage folder. To build the image follow the steps below:

1. **Fork & Clone the Repository**:
    - First, fork the repository to your own GitHub account by clicking the "Fork" button on the repository page.
    - Then, clone your forked repository:
    ```sh
    git clone https://github.com/<your_fork>/aks-platform-engineering.git
    cd aks-platform-engineering

2. **Install Dependencies**: Ensure all dependencies are installed by running:

    ```sh
    yarn install
    ```

3. **Build the Project**: Run the build script defined in your `package.json`. Based on your previous commands, it looks like you need to build the backend:

    ```sh
    yarn build:backend --config ./app-config-local.yaml
    ```

4. **Optional - Run the Application Locally**: After building the project, you can run it locally. Ensure that all necessary environment variables are set:

    ```sh
    export BASE_URL=https://your-local-base-url.com
    export POSTGRES_HOST=your-local-postgres-host
    export POSTGRES_PORT=your-local-postgres-port
    export POSTGRES_USER=your-local-postgres-user
    export POSTGRES_PASSWORD=your-local-postgres-password
    export POSTGRES_DB=your-local-postgres-db

    yarn start
    ```

5. **Ensure Azure CLI is Installed**: Make sure you have the Azure CLI installed and logged in. If not, install it from [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) and log in using:

    ```sh
    az login
    ```

6. **Set Environment Variables**: Set the `ACR_NAME` and `RESOURCE_GROUP` environment variables:

    ```sh
    export ACR_NAME=your_acr_name
    export RESOURCE_GROUP=your_resource_group
    ```

7. **Build the Docker Image Locally**: Use the `docker build` command to build your Docker image:

    ```sh
    docker build -t $ACR_NAME.azurecr.io/my-backend-app:latest .
    ```

8. **Login to Azure Container Registry**: Use the Azure CLI to log in to your ACR:

    ```sh
    az acr login --name $ACR_NAME --resource-group $RESOURCE_GROUP
    ```

9. **Push the Docker Image to ACR**: Push the built image to your ACR:

    ```sh
    docker push $ACR_NAME.azurecr.io/my-backend-app:latest
    ```

10. **Verify the Image in ACR**: You can verify that the image has been pushed to ACR by listing the repositories:

    ```sh
    az acr repository list --name $ACR_NAME --output table
    ```


## Getting Started

  To get started with Backstage in this project, follow these steps:

1. **Fork & Clone the Repository**:
    - First, fork the repository to your own GitHub account by clicking the "Fork" button on the repository page.
    - Then, clone your forked repository:
    ```sh
    git clone https://github.com/<your_fork>/aks-platform-engineering.git
    cd aks-platform-engineering
    ```

2. **Deploy Terraform with Backstage**:
    To deploy Backstage, you can use the provided Terraform scripts. Navigate to the `terraform` directory and apply the configuration:
    ```sh
    cd terraform
    terraform apply -var infrastructure_provider=crossplane -var build_backstage=true -var gitops_addons_org=https://github.com/<your_gh_username/org> -var github_token=<your_pat_token> --auto-approve
    ```

    > **Note:** There is an alert generated in the terraform output that informs you to go to your newly created backstage SP and "Grant Admin" to the SP. This is because onboarding all users from your entra tenant requires admin privileges. If you don't do this prior to Backstage deploying you will have to wait for the scheduled task to run again (Once an hour) or manually populate the users in the backstage user table. 


## Additional Resources

- [Backstage Documentation](https://backstage.io/docs)
- [Spotify's Backstage Blog](https://backstage.io/blog)
- [Project README](../README.md)

