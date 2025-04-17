#!/bin/bash

# Ensure terraform directory exists
mkdir -p terraform
echo "📁 Ensured 'terraform/' directory exists."

# Ask for Service Account name
read -p "🔐 Enter your Service Account name: " SERVICE_ACCOUNT
if [[ -z "$SERVICE_ACCOUNT" ]]; then
  echo "❌ Service Account name is required."
  exit 1
fi

# Ask for Service Key file path
read -p "📄 Enter your Service Account key: " KEY_PATH
if [[ -z "$KEY_PATH" ]]; then
  echo "❌ Service Account name is required"
  exit 1
fi

# Get Role data
ROLE_ARN=$(aws iam list-roles --query "Roles[?contains(RoleName, 'eksctl-testcluster-cluster')].[Arn]" --output text)
ROLE_ID=$(aws iam list-roles --query "Roles[?contains(RoleName, 'eksctl-testcluster-cluster')].[RoleId]" --output text)

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



export illumio_cloudsecure_client_secret