#!/bin/bash

# Script to deploy ECS Event Forwarder CloudFormation stack
# This forwards ECS events from source account to common account SNS topic

set -e

# Default values
ENVIRONMENT_PREFIX=${1:-dev-an2d}
TARGET_SNS_ARN=${2:-arn:aws:sns:ap-northeast-2:971924526134:com-an2p-abnormal-resource-event-topic}
REGION=${3:-ap-northeast-2}
STACK_NAME="${ENVIRONMENT_PREFIX}-ecs-event-forwarder-stack"
TEMPLATE_FILE="ecs-event-forwarder.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}ECS Event Forwarder Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}Error: Template file $TEMPLATE_FILE not found!${NC}"
    exit 1
fi

# Display deployment parameters
echo -e "${YELLOW}Deployment Parameters:${NC}"
echo -e "  Stack Name:        ${STACK_NAME}"
echo -e "  Environment:       ${ENVIRONMENT_PREFIX}"
echo -e "  Target SNS ARN:    ${TARGET_SNS_ARN}"
echo -e "  Region:            ${REGION}"
echo -e "  Template File:     ${TEMPLATE_FILE}"
echo ""

# Validate template
echo -e "${YELLOW}Validating CloudFormation template...${NC}"
aws cloudformation validate-template \
    --template-body file://${TEMPLATE_FILE} \
    --region ${REGION} > /dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Template validation successful${NC}"
else
    echo -e "${RED}✗ Template validation failed${NC}"
    exit 1
fi

# Deploy the stack
echo ""
echo -e "${YELLOW}Deploying CloudFormation stack...${NC}"
aws cloudformation deploy \
    --template-file ${TEMPLATE_FILE} \
    --stack-name ${STACK_NAME} \
    --parameter-overrides \
        ParameterKey=EnvironmentPrefix,ParameterValue="${ENVIRONMENT_PREFIX}" \
        ParameterKey=TargetSNSArn,ParameterValue="${TARGET_SNS_ARN}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region ${REGION}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Stack deployment successful${NC}"
    
    # Get stack outputs
    echo ""
    echo -e "${YELLOW}Stack Outputs:${NC}"
    aws cloudformation describe-stacks \
        --stack-name ${STACK_NAME} \
        --region ${REGION} \
        --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
        --output table
else
    echo -e "${RED}✗ Stack deployment failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "1. Verify the EventBridge rule is active in the AWS Console"
echo -e "2. Ensure the common account SNS topic has proper permissions"
echo -e "3. Test with a manual ECS task stop to verify event forwarding"
echo ""
echo -e "${YELLOW}To check rule status:${NC}"
echo -e "aws events describe-rule --name ${ENVIRONMENT_PREFIX}-ecs-event-forwarder-rule --region ${REGION}"
echo ""
echo -e "${YELLOW}To delete this stack:${NC}"
echo -e "aws cloudformation delete-stack --stack-name ${STACK_NAME} --region ${REGION}"