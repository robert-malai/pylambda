#!/usr/bin/env bash

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account')
TERRAFORM_BUCKET=${ACCOUNT_ID}-terraform-state
TERRAFORM_LOCK=terraform_locks

# Check if the state bucked exists
aws s3api head-bucket --bucket "${TERRAFORM_BUCKET}" 2> /dev/null
if [ $? -ne 0 ]; then
    echo "Creating bucket ${TERRAFORM_BUCKET}..."
    aws s3 mb s3://${TERRAFORM_BUCKET}
    #aws s3api put-bucket-versioning --bucket ${TERRAFORM_BUCKET} --versioning-configuration Status=Enabled
fi

# Check if the dynamodb table exists
aws dynamodb list-tables | grep -q ${TERRAFORM_LOCK}
if [ $? -ne 0 ]; then
    echo "Creating DynamoDb table ${TERRAFORM_LOCK}..."
    aws dynamodb create-table \
         --region us-east-1 \
         --table-name ${TERRAFORM_LOCK} \
         --attribute-definitions AttributeName=LockID,AttributeType=S \
         --key-schema AttributeName=LockID,KeyType=HASH \
         --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1
fi