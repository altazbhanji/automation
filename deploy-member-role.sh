#!/bin/bash

set -e

STACK_NAME="idle-shutdown-member-role"
TEMPLATE_FILE="member-account-role.yaml"
REGION="us-east-1"

CENTRAL_ACCOUNT_ID="123456789012"  # Replace with your central account ID
ROLE_NAME="IdleInstanceShutdownRole"
USE_EXTERNAL_ID="false"  # Set to "true" if you want to use external ID
EXTERNAL_ID=""  # Set this if USE_EXTERNAL_ID is "true"

echo "Deploying Member Account Role CloudFormation Stack..."
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Central Account ID: $CENTRAL_ACCOUNT_ID"
echo "Role Name: $ROLE_NAME"
echo "Use External ID: $USE_EXTERNAL_ID"
echo "External ID: $EXTERNAL_ID"
echo ""

if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "Error: AWS CLI is not configured or credentials are invalid"
    echo "Please run 'aws configure' to set up your credentials"
    exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file '$TEMPLATE_FILE' not found"
    exit 1
fi

echo "Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body file://$TEMPLATE_FILE \
    --region $REGION

if [ $? -eq 0 ]; then
    echo "Template validation successful!"
else
    echo "Template validation failed!"
    exit 1
fi

if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION > /dev/null 2>&1; then
    echo "Stack '$STACK_NAME' already exists. Updating..."
    
    aws cloudformation update-stack \
        --stack-name $STACK_NAME \
        --template-body file://$TEMPLATE_FILE \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION \
        --parameters \
            ParameterKey=CentralAccountId,ParameterValue=$CENTRAL_ACCOUNT_ID \
            ParameterKey=RoleName,ParameterValue=$ROLE_NAME \
            ParameterKey=UseExternalId,ParameterValue=$USE_EXTERNAL_ID \
            ParameterKey=ExternalId,ParameterValue="$EXTERNAL_ID"
    
    echo "Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete \
        --stack-name $STACK_NAME \
        --region $REGION
else
    echo "Creating new stack '$STACK_NAME'..."
    
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://$TEMPLATE_FILE \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION \
        --parameters \
            ParameterKey=CentralAccountId,ParameterValue=$CENTRAL_ACCOUNT_ID \
            ParameterKey=RoleName,ParameterValue=$ROLE_NAME \
            ParameterKey=UseExternalId,ParameterValue=$USE_EXTERNAL_ID \
            ParameterKey=ExternalId,ParameterValue="$EXTERNAL_ID"
    
    echo "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete \
        --stack-name $STACK_NAME \
        --region $REGION
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "Stack deployment successful!"
    echo ""
    echo "Stack Outputs:"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue,Description]' \
        --output table
    
    echo ""
    echo "Next Steps:"
    echo "1. Deploy this same stack in all member accounts where you want idle instance shutdown"
    echo "2. Deploy the central account template (idle-instance-shutdown.yaml) in your management account"
    echo "3. Use the same RoleName ($ROLE_NAME) in the central account template parameters"
    if [ "$USE_EXTERNAL_ID" = "true" ]; then
        echo "4. Use the same ExternalId ($EXTERNAL_ID) in the central account template parameters"
    fi
    echo ""
    echo "The central account Lambda will now be able to assume this role and manage EC2 instances."
else
    echo "Stack deployment failed!"
    exit 1
fi
