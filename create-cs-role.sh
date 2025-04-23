#!/bin/bash

# filepath: /Users/jeff.schmitz/devstuff/scripts/agentless/create-cs-role.sh

# ============================
# Configuration Variables
# ============================
ROLE_NAME="IllumioCloudIntegrationRole"
DIR="preonboarding"
TRUST_POLICY_FILE="trust-policy.json"
READ_POLICY_FILE="readonly.json"
WRITE_POLICY_FILE="readwrite.json"
REGION="us-west-1"
RANDOM_NUMBER=$(tr -dc '0-9' < /dev/urandom | head -c 36)

VPC_NAME="IllumioVPC"
SUBNET_NAME="IllumioSubnet"

CLUSTER_NAME="illumioholcluster"
RANDOM_SUFFIX=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)
BUCKET_NAME="vpc-flowlogs-$CLUSTER_NAME-$RANDOM_SUFFIX"

# ============================
# Check Prerequisites
# ============================
function check_prerequisites() {
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI could not be found. Please install it first."
        exit 1
    fi
}

# ============================
# Create Trust Policy File
# ============================
function create_trust_policy() {
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
}

# ============================
# Create IAM Role
# ============================
function create_iam_role() {
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
}

# ============================
# Attach Policies
# ============================
function attach_policies() {
    echo "Attaching managed policy: SecurityAudit"
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/SecurityAudit \
        --region $REGION

    echo "Creating and attaching inline read-only policy..."
    cat > $READ_POLICY_FILE <<EOF
[INSERT_JSON_READ_POLICY_HERE]
EOF
    aws iam put-role-policy \
        --role-name $ROLE_NAME \
        --policy-name IllumioCloudAWSIntegrationPolicy \
        --policy-document file://$DIR/$READ_POLICY_FILE \
        --region $REGION

    echo "Creating and attaching inline write policy..."
    cat > $WRITE_POLICY_FILE <<EOF
[INSERT_JSON_WRITE_POLICY_HERE]
EOF
    aws iam put-role-policy \
        --role-name $ROLE_NAME \
        --policy-name IllumioCloudAWSProtectionPolicy \
        --policy-document file://$DIR/$WRITE_POLICY_FILE \
        --region $REGION
}

# # ============================
# # Create VPC
# # ============================
# function create_vpc() {
#     echo "Creating VPC: $VPC_NAME"
#     VPC_ID=$(aws ec2 create-vpc --cidr-block $CIDR_BLOCK --query 'Vpc.VpcId' --output text --region $REGION)
#     echo "✅ Created VPC with ID: $VPC_ID"

#     echo "Tagging VPC with Name: $VPC_NAME"
#     aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_NAME --region $REGION
# }


# ============================
# Create VPC Flow Logs
# ============================
function create_vpc_flow_logs() {
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
}
# ============================
# Add CS VPC Flowlog S3 Bucket Policy
# ============================
function updatevpcflowloggpolicy() {
echo "✅ Applying IllumioBucketListAccessbucket policy to $BUCKET_NAME..."
aws iam put-role-policy \
  --role-name IllumioCloudIntegrationRole \
  --policy-name IllumioCloudBucketListPolicy \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Sid\": \"IllumioBucketListAccess\",
        \"Action\": [\"s3:ListBucket\"],
        \"Resource\": [\"${OBJECT_ARN}\"]
      }
    ]
  }"

echo "✅ Applying IllumioBucketReadAccess policy to $BUCKET_NAME..."
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name IllumioCloudBucketReadPolicy \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Sid\": \"IllumioBucketReadAccess\",
        \"Action\": [\"s3:GetObject\"],
        \"Resource\": [\"${OBJECT_ARN}\"]
      }
    ]
  }"

echo "✅ Applying IllumioBucketGetLocationAccess policy to $BUCKET_NAME..."
aws iam put-role-policy \
  --role-name $ROLE_NAME \
  --policy-name IllumioCloudBucketGetLocationPolicy \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Sid\": \"IllumioBucketGetLocationAccess\",
        \"Action\": [\"s3:GetBucketLocation\"],
        \"Resource\": [\"$BUCKET_ARN\"]
      }
    ]
  }"
}
# ============================
# Collect User Input
# ============================
function collect_user_input() {
    read -p "🔐 Enter your Service Account name: " CLIENT_ID
    if [[ -z "$CLIENT_ID" ]]; then
        echo "❌ Service Account name is required."
        exit 1
    fi

    if [[ ! "$CLIENT_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "❌ CLIENT_ID contains invalid characters. Only alphanumeric, dashes, and underscores are allowed."
        exit 1
    fi

    read -p "📄 Enter your Service Account key: " CLIENT_SECRET
    if [[ -z "$CLIENT_SECRET" ]]; then
        echo "❌ Service Account key is required."
        exit 1
    fi

    if [[ ! "$CLIENT_SECRET" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "❌ CLIENT_SECRET contains invalid characters. Only alphanumeric, dashes, and underscores are allowed."
        exit 1
    fi
}

# ============================
# Retrieve AWS Data
# ============================
function retrieve_aws_data() {
    ROLE_ARN=$(aws iam list-roles --query "Roles[?contains(RoleName, '$ROLE_NAME')].[Arn]" --output text)
   # ROLE_ID=$(aws iam list-roles --query "Roles[?contains(RoleName, '$ROLE_NAME')].[RoleId]" --output text)
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

    if [[ -z "$ROLE_ARN" ]]; then
        echo "❌ Could not retrieve Role ARN for $ROLE_NAME"
        exit 1
    fi
    echo "✅ Cluster Role ARN: $ROLE_ARN"

    # if [[ -z "$ROLE_ID" ]]; then
    #     echo "❌ Could not retrieve Role ID for $ROLE_NAME"
    #     exit 1
    # fi
    echo "✅ Cluster Role ID: $ROLE_ID"

    if [[ -z "$ACCOUNT_ID" ]]; then
        echo "❌ Could not retrieve Account ID"
        exit 1
    fi
    echo "✅ Cluster Account ID: $ACCOUNT_ID"
}

# ============================
# Run Terraform
# ============================
function run_terraform() {
    export TF_VAR_illumio_cloudsecure_client_secret=$CLIENT_SECRET
    export TF_VAR_illumio_cloudsecure_client_id=$CLIENT_ID

    terraform -chdir=onboarding init
    terraform -chdir=onboarding apply \
        -var "role_arn=$ROLE_ARN" \
        -var "role_external_id=$RANDOM_NUMBER" \
        -var "aws_account_id=$ACCOUNT_ID" \
        -var "storage_bucket_arn=$BUCKET_ARN" \
        -auto-approve
}

# ============================
# Main Script Execution
# ============================
check_prerequisites
create_trust_policy
create_iam_role
attach_policies
create_vpc_flow_logs
updatevpcflowloggpolicy
collect_user_input
retrieve_aws_data
run_terraform
