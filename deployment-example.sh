#!/bin/bash


set -e

STACK_NAME="idle-instance-shutdown"
TEMPLATE_FILE="idle-instance-shutdown.yaml"
REGION="us-east-1"

IDLE_THRESHOLD_MINUTES=90
CPU_THRESHOLD_PERCENT=3
NETWORK_THRESHOLD_BYTES=500000
SCHEDULE_EXPRESSION="rate(10 minutes)"
EXCLUDE_TAGS="Environment=Production,Critical=true,DoNotShutdown=true"
CROSS_ACCOUNT_ROLE_NAME="IdleInstanceShutdownRole"
CROSS_ACCOUNT_EXTERNAL_ID=""

echo "Deploying Idle Instance Shutdown CloudFormation Stack..."
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Idle Threshold: $IDLE_THRESHOLD_MINUTES minutes"
echo "CPU Threshold: $CPU_THRESHOLD_PERCENT%"
echo "Network Threshold: $NETWORK_THRESHOLD_BYTES bytes"
echo "Check Schedule: $SCHEDULE_EXPRESSION"
echo "Exclude Tags: $EXCLUDE_TAGS"
echo "Cross-Account Role Name: $CROSS_ACCOUNT_ROLE_NAME"
echo "Cross-Account External ID: $CROSS_ACCOUNT_EXTERNAL_ID"
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
            ParameterKey=IdleThresholdMinutes,ParameterValue=$IDLE_THRESHOLD_MINUTES \
            ParameterKey=CPUThresholdPercent,ParameterValue=$CPU_THRESHOLD_PERCENT \
            ParameterKey=NetworkThresholdBytes,ParameterValue=$NETWORK_THRESHOLD_BYTES \
            ParameterKey=ScheduleExpression,ParameterValue="$SCHEDULE_EXPRESSION" \
            ParameterKey=ExcludeInstanceTags,ParameterValue="$EXCLUDE_TAGS" \
            ParameterKey=CrossAccountRoleName,ParameterValue="$CROSS_ACCOUNT_ROLE_NAME" \
            ParameterKey=CrossAccountExternalId,ParameterValue="$CROSS_ACCOUNT_EXTERNAL_ID"
    
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
            ParameterKey=IdleThresholdMinutes,ParameterValue=$IDLE_THRESHOLD_MINUTES \
            ParameterKey=CPUThresholdPercent,ParameterValue=$CPU_THRESHOLD_PERCENT \
            ParameterKey=NetworkThresholdBytes,ParameterValue=$NETWORK_THRESHOLD_BYTES \
            ParameterKey=ScheduleExpression,ParameterValue="$SCHEDULE_EXPRESSION" \
            ParameterKey=ExcludeInstanceTags,ParameterValue="$EXCLUDE_TAGS" \
            ParameterKey=CrossAccountRoleName,ParameterValue="$CROSS_ACCOUNT_ROLE_NAME" \
            ParameterKey=CrossAccountExternalId,ParameterValue="$CROSS_ACCOUNT_EXTERNAL_ID"
    
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
    echo "1. Monitor the Lambda function logs in CloudWatch: /aws/lambda/$STACK_NAME-idle-instance-shutdown"
    echo "2. Subscribe to the SNS topic for shutdown notifications"
    echo "3. Add exclusion tags to instances you want to protect:"
    echo "   - Environment=Production"
    echo "   - DoNotShutdown=true"
    echo "   - Critical=true"
    echo ""
    echo "The system will start checking for idle instances based on your schedule: $SCHEDULE_EXPRESSION"
else
    echo "Stack deployment failed!"
    exit 1
fi
