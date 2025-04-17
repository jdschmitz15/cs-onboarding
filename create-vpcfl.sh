#!/bin/bash

CLUSTER_NAME="testcluster"
REGION="us-west-1"

# Generate random suffix and bucket name
RANDOM_SUFFIX=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)
BUCKET_NAME="vpc-flowlogs-$CLUSTER_NAME-$RANDOM_SUFFIX"


# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Get VPC ID from EKS cluster
VPC_ID=$(aws eks describe-cluster \
  --region $REGION \
  --name $CLUSTER_NAME \
  --query "cluster.resourcesVpcConfig.vpcId" \
  --output text)

if [[ -z "$VPC_ID" ]]; then
  echo "❌ Could not retrieve VPC ID for cluster $CLUSTER_NAME"
  exit 1
fi

echo "✅ Cluster VPC ID: $VPC_ID"

# Create S3 bucket (if not exists)
echo "🪣 Ensuring S3 bucket $BUCKET_NAME exists..."
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || true

# Define ARNs
BUCKET_ARN="arn:aws:s3:::$BUCKET_NAME"
OBJECT_ARN="$BUCKET_ARN/AWSLogs/$ACCOUNT_ID/*"

# Create bucket policy file
cat > flowlog-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSLogDeliveryWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "$OBJECT_ARN",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    },
    {
      "Sid": "AWSLogDeliveryGetAcl",
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "$BUCKET_ARN"
    }
  ]
}
EOF

# Apply bucket policy
echo "🔐 Applying bucket policy to $BUCKET_NAME..."
aws s3api put-bucket-policy \
  --bucket "$BUCKET_NAME" \
  --policy file://flowlog-policy.json

# Create flow log
echo "📊 Enabling VPC Flow Logs to S3..."
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids "$VPC_ID" \
  --traffic-type ALL \
  --log-destination-type s3 \
  --log-destination "$BUCKET_ARN" \
  --region "$REGION"

echo "✅ Flow logs enabled for VPC $VPC_ID and sent to bucket $BUCKET_NAME"
