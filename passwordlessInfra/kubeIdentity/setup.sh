#!/bin/bash

# This script configures a self hosted kubernetes cluster with workload identity using Azure AD.

# Replace the following variables with your actual values:
# export AZURE_STORAGE_ACCOUNT="your_storage_account_name"
# export AZURE_STORAGE_CONTAINER="your_storage_container_name"
# export AZURE_TENANT_ID="your_azure_tenant_id"
# export AZURE_SUBSCRIPTION_ID="your_subscription_id"
# export AAD_APPLICATION_ID="your_aad_application_id"
# export RESOURCE_GROUP_NAME="your_resource_group_name"
# export LOCATION="your_location"  # e.g., eastus, westus, centralus
# export SERVICE_ACCOUNT_NAMESPACE="default"  # Or your desired namespace
# export SERVICE_ACCOUNT_NAME="my-service-account"  # Or your desired service account name


# Ensure that the Azure AD application has the necessary permissions and is properly configured for your use case.

# Azure CLI Login:
# The az login command will prompt you to authenticate. Make sure to authenticate with an account that has the necessary permissions to execute the Azure commands in the script.
# Docker Group Membership:
# After running this script, you might need to log out and log back in for Docker group membership changes to take effect.
# Minikube Considerations:
# This script starts Minikube with the required configurations to act as an OIDC issuer and installs the necessary tools and components.
# Service Account Creation:
# The script uses azwi to link the Kubernetes Service Account with the existing Azure AD application.
# Handle Secrets Securely:
# Ensure that any client secrets or certificates associated with the Azure AD application are handled securely in your environment.

# Running the script:
# chmod +x setup_minikube_oidc.sh
# ./setup_minikube_oidc.sh

# Exit immediately if a command exits with a non-zero status.
set -e

# Update system packages
echo "Updating system packages..."
sudo apt-get update -y

# Install dependencies
echo "Installing dependencies..."
sudo apt-get install -y curl wget apt-transport-https gnupg lsb-release software-properties-common ca-certificates openssl

# Install Docker
echo "Installing Docker..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER

# Install kubectl
echo "Installing kubectl..."
sudo curl -fsSLo /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl

# Install Minikube
echo "Installing Minikube..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64

# Generate RSA keys
echo "Generating RSA keys..."
openssl genrsa -out /home/$USER/sa.key 2048
openssl rsa -in /home/$USER/sa.key -pubout -out /home/$USER/sa.pub

# Install Azure CLI
echo "Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash


# Set Azure variables (replace these with your actual values)
echo "Setting Azure environment variables..."
export AZURE_STORAGE_ACCOUNT="phcloudbrewoidc"
export AZURE_STORAGE_CONTAINER="oidccontainer"
export AZURE_TENANT_ID="7135bcf1-5a12-4e82-ad41-c263afa243e8"
export AZURE_SUBSCRIPTION_ID="ede0939c-80c4-4dfe-bf3d-84521f3f6d1f"
export AAD_APPLICATION_ID="3f308513-c3f1-453c-9bfe-45d455762a8b"
export RESOURCE_GROUP_NAME="oidc-resource-group"
export LOCATION="swedencentral"
export SERVICE_ACCOUNT_NAMESPACE="phcloudbrew"
export SERVICE_ACCOUNT_NAME="phcloudbrewapp"

# Login to Azure
echo "Logging into Azure..."
az login --tenant $AZURE_TENANT_ID --use-device-code

# Create resource group if it doesn't exist
echo "Checking if resource group exists..."
if [ $(az group exists --name $RESOURCE_GROUP_NAME) = false ]; then
    echo "Creating resource group $RESOURCE_GROUP_NAME..."
    az group create --name $RESOURCE_GROUP_NAME --location $LOCATION
else
    echo "Resource group $RESOURCE_GROUP_NAME already exists."
fi

# Check if storage account exists
echo "Checking if storage account exists..."
if ! az storage account check-name --name $AZURE_STORAGE_ACCOUNT --query "nameAvailable" --output tsv; then
    echo "Storage account $AZURE_STORAGE_ACCOUNT already exists."
else
    echo "Creating storage account $AZURE_STORAGE_ACCOUNT..."
    az storage account create --name $AZURE_STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP_NAME --location $LOCATION --sku Standard_LRS --allow-blob-public-access true
fi
# Get storage account key
echo "Retrieving storage account key..."
export AZURE_STORAGE_KEY=$(az storage account keys list --account-name $AZURE_STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP_NAME --query "[0].value" -o tsv)

# Create storage container
echo "Creating storage container..."
az storage container create --name $AZURE_STORAGE_CONTAINER --account-name $AZURE_STORAGE_ACCOUNT --account-key $AZURE_STORAGE_KEY --public-access blob

# Generate discovery document
echo "Generating OpenID Connect discovery document..."
cat <<EOF > openid-configuration.json
{
  "issuer": "https://${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_STORAGE_CONTAINER}/",
  "jwks_uri": "https://${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_STORAGE_CONTAINER}/openid/v1/jwks",
  "response_types_supported": [
    "id_token"
  ],
  "subject_types_supported": [
    "public"
  ],
  "id_token_signing_alg_values_supported": [
    "RS256"
  ]
}
EOF

# Upload discovery document
echo "Uploading discovery document to Azure Storage..."
az storage blob upload \
  --container-name "${AZURE_STORAGE_CONTAINER}" \
  --file openid-configuration.json \
  --name .well-known/openid-configuration \
  --account-name $AZURE_STORAGE_ACCOUNT \
  --account-key $AZURE_STORAGE_KEY \
  --overwrite

# Verify discovery document
echo "Verifying discovery document..."
curl -s "https://${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_STORAGE_CONTAINER}/.well-known/openid-configuration"

# Install azwi (Azure Workload Identity)
echo "Installing azwi..."
curl -L https://github.com/Azure/azure-workload-identity/releases/download/v1.3.0/azwi-v1.3.0-linux-amd64.tar.gz | tar -xz
sudo mv azwi /usr/local/bin/

# Generate JWKS document
echo "Generating JWKS document..."
azwi jwks --public-keys /home/$USER/sa.pub --output-file jwks.json

# Upload JWKS document
echo "Uploading JWKS document to Azure Storage..."
az storage blob upload \
  --container-name "${AZURE_STORAGE_CONTAINER}" \
  --file jwks.json \
  --name openid/v1/jwks \
  --account-name $AZURE_STORAGE_ACCOUNT \
  --account-key $AZURE_STORAGE_KEY \
  --overwrite

# Verify JWKS document
echo "Verifying JWKS document..."
curl -s "https://${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_STORAGE_CONTAINER}/openid/v1/jwks"

# Start Minikube with required configurations
echo "Starting Minikube to set up required configurations..."
sudo usermod -aG docker $USER

minikube start
minikube cp /home/$USER/sa.key /var/lib/minikube/certs/sa.key
minikube cp /home/$USER/sa.pub /var/lib/minikube/certs/sa.pub
minikube stop


echo "Starting Minikube with new config..."
minikube start \
  --extra-config=apiserver.service-account-issuer="https://${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_STORAGE_CONTAINER}/" \
  --extra-config=apiserver.service-account-signing-key-file="/var/lib/minikube/certs/sa.key" \
  --extra-config=apiserver.service-account-key-file="/var/lib/minikube/certs/sa.pub" \
  --extra-config=controller-manager.service-account-private-key-file="/var/lib/minikube/certs/sa.key"


# Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# Add azure-workload-identity Helm repo
echo "Adding azure-workload-identity Helm repository..."
helm repo add azure-workload-identity https://azure.github.io/azure-workload-identity/charts
helm repo update

# Install workload-identity-webhook via Helm
echo "Installing workload-identity-webhook..."
helm install workload-identity-webhook azure-workload-identity/workload-identity-webhook \
  --namespace azure-workload-identity-system \
  --create-namespace \
  --set azureTenantID="${AZURE_TENANT_ID}"

# Create Service Account via azwi
echo "Creating Service Account via azwi..."

# Use azwi to create the Kubernetes Service Account and link it to the Azure AD application
echo "Linking Kubernetes Service Account with Azure AD application using azwi..."
kubectl create namespace $SERVICE_ACCOUNT_NAMESPACE

azwi sa create phase service-account\
  --service-account-namespace $SERVICE_ACCOUNT_NAMESPACE \
  --service-account-name $SERVICE_ACCOUNT_NAME \
  --aad-application-client-id $AAD_APPLICATION_ID 

echo "Restarting cluster just in case, as previously mutating webhook ran with failures"

echo "Service Account creation complete!"

echo ""
echo "----------------------------------------"
echo "Federated Identity Configuration Details"
echo "----------------------------------------"
echo "Issuer URL:"
echo "https://${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_STORAGE_CONTAINER}/"
echo ""
echo "Subject Identifier:"
echo "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}"
echo "----------------------------------------"
echo ""

echo "Installation and configuration complete!"
