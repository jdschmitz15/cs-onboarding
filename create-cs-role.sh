#!/bin/bash

ROLE_NAME="IllumioCloudIntegrationRole"
DIR="preonboarding"
TRUST_POLICY_FILE="trust-policy.json"
READ_POLICY_FILE="readonly.json"
WRITE_POLICY_FILE="readwrite.json"
REGION="us-west-1"

echo "Creating IAM Role: $ROLE_NAME"
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://$DIR/$TRUST_POLICY_FILE \
  --region $REGION

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
