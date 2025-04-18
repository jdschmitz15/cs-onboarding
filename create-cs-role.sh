#!/bin/bash

ROLE_NAME="IllumioCloudIntegrationRole"
DIR="preonboarding"
TRUST_POLICY_FILE="trust-policy.json"
READ_POLICY_FILE="readonly.json"
WRITE_POLICY_FILE="readwrite.json"
REGION="us-west-1"

RANDOM_NUMBER=$(tr -dc '0-9' < /dev/urandom | head -c 36)

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null
then
    echo "❌ AWS CLI could not be found. Please install it first."
    exit 1
fi

cat > $DIR/$TRUST_POLICY_FILE <<EOF
{
  "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::712001342241:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "${RANDOM_NUMBER}"
                }
            }
        }
    ]
}
EOF

# Check if the role already exists
echo "Checking if IAM Role $ROLE_NAME already exists..."
if aws iam get-role --role-name $ROLE_NAME --region $REGION > /dev/null 2>&1; then
  echo "IAM Role $ROLE_NAME already exists. Skipping creation."
else
  echo "Creating IAM Role: $ROLE_NAME"
  aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file://$DIR/$TRUST_POLICY_FILE \
    --region $REGION
fi

echo "Attaching managed policy: SecurityAudit"
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/SecurityAudit \
  --region $REGION

echo "Creating inline read-only policy..."
cat > $READ_POLICY_FILE <<EOF
[INSERT_JSON_READ_POLICY_HERE]
EOF

echo "Attaching inline read-only policy..."
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name IllumioCloudAWSIntegrationPolicy \
  --policy-document file://$DIR/$READ_POLICY_FILE \
  --region $REGION

echo "Creating inline write policy..."
cat > $WRITE_POLICY_FILE <<EOF
[INSERT_JSON_WRITE_POLICY_HERE]
EOF

echo "Attaching inline write policy..."
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name IllumioCloudAWSProtectionPolicy \
  --policy-document file://$DIR/$WRITE_POLICY_FILE \
  --region $REGION

echo "🎉 IAM Role $ROLE_NAME created and configured successfully!"

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
#terraform -chdir=onboarding plan -var "role_arn=$ROLE_ARN" -var "role_id=$ROLE_ID" -var "aws_account_id=$ACCOUNT_ID"
terraform -chdir=onboarding apply -var "role_arn=$ROLE_ARN" -var "role_external_id=$RANDOM_NUMBER" -var "aws_account_id=$ACCOUNT_ID" -auto-approve
