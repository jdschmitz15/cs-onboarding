#!/bin/bash

# Ensure terraform directory exists
# mkdir -p terraform
# echo "📁 Ensured 'terraform/' directory exists."

# Ask for Service Account name
read -p "🔐 Enter your Service Account name: " CLIENT_ID
if [[ -z "$CLIENT_ID" ]]; then
  echo "❌ Service Account name is required."
  exit 1
fi

# Validate CLIENT_ID
if [[ ! "$CLIENT_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "❌ CLIENT_ID contains invalid characters. Only alphanumeric, dashes, and underscores are allowed."
  exit 1
fi

# Ask for Service Key file path
read -p "📄 Enter your Service Account key: " CLIENT_SECRET
if [[ -z "$CLIENT_SECRET" ]]; then
  echo "❌ Service Account name is required"
  exit 1
fi

# Validate CLIENT_SECRET
if [[ ! "$CLIENT_SECRET" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "❌ CLIENT_SECRET contains invalid characters. Only alphanumeric, dashes, and underscores are allowed."
  exit 1
fi

# Get Role data
ROLE_ARN=$(aws iam list-roles --query "Roles[?contains(RoleName, 'IllumioCloudIntegrationRole')].[Arn]" --output text)
ROLE_ID=$(aws iam list-roles --query "Roles[?contains(RoleName, 'IllumioCloudIntegrationRole')].[RoleId]" --output text)

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [[ -z "$ROLE_ARN" ]]; then
  echo "❌ Could not retrieve Role ARN for cluster $CLUSTER_NAME"
  exit 1
fi
echo "✅ Cluster Role ARN: $ROLE_ARN"
if [[ -z "$ROLE_ID" ]]; then
  echo "❌ Could not retrieve Role ID for cluster $CLUSTER_NAME"
  exit 1
fi
echo "✅ Cluster Role ID: $ROLE_ID"
if [[ -z "$ACCOUNT_ID" ]]; then
  echo "❌ Could not retrieve Account ID for cluster $CLUSTER_NAME"
  exit 1
fi
echo "✅ Cluster Account ID: $ACCOUNT_ID"

# Export Terraform variables
export TF_VAR_illumio_cloudsecure_client_secret=$CLIENT_SECRET
export TF_VAR_illumio_cloudsecure_client_id=$CLIENT_ID

terraform -chdir=onboarding init
terraform -chdir=onboarding plan -var "role_arn=$ROLE_ARN" -var "role_id=$ROLE_ID" -var "aws_account_id=$ACCOUNT_ID"
terraform -chdir=onboarding apply -var "role_arn=$ROLE_ARN" -var "role_id=$ROLE_ID" -var "aws_account_id=$ACCOUNT_ID" -auto-approve