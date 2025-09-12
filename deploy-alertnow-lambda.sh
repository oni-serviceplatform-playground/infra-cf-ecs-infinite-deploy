#!/bin/bash

# Script to deploy AlertNow Lambda CloudFormation stack in Common Account
# This Lambda processes ECS events from SNS and sends alerts to AlertNow ITGR

set -e

# Default values
WEBHOOK_URL=${1:-https://alertnowitgr.opsnow.com/integration/standard/v1/9dfa2ece68ec5311f05bed1806b77546d703}
SNS_TOPIC_ARN=${2:-arn:aws:sns:ap-northeast-2:971924526134:com-an2p-abnormal-resource-event-topic}
REGION=${3:-ap-northeast-2}
STACK_NAME="com-an2p-ecs-alertnow-lambda-stack"
TEMPLATE_FILE="common-account-ecs-alertnow-lambda.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}AlertNow Lambda Deployment Script${NC}"
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
echo -e "  SNS Topic ARN:     ${SNS_TOPIC_ARN}"
echo -e "  Region:            ${REGION}"
echo -e "  Template File:     ${TEMPLATE_FILE}"
echo -e "  AlertNow URL:      [HIDDEN]"
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
        ParameterKey=AlertNowWebhookUrl,ParameterValue="${WEBHOOK_URL}" \
        ParameterKey=ExistingSNSTopicArn,ParameterValue="${SNS_TOPIC_ARN}" \
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
echo -e "1. Verify the Lambda function is created in the AWS Console"
echo -e "2. Check SNS subscription is active"
echo -e "3. Configure SNS Topic policy to allow source accounts to publish"
echo -e "4. Test with a manual SNS message to verify AlertNow integration"
echo ""
echo -e "${YELLOW}To test the Lambda function:${NC}"
echo -e "aws lambda invoke --function-name com-an2p-ecs-task-failure-alertnow-notifier --payload '<test-json>' response.json --region ${REGION}"
echo ""
echo -e "${YELLOW}To view Lambda logs:${NC}"
echo -e "aws logs tail /aws/lambda/com-an2p-ecs-task-failure-alertnow-notifier --follow --region ${REGION}"
echo ""
echo -e "${YELLOW}To delete this stack:${NC}"
echo -e "aws cloudformation delete-stack --stack-name ${STACK_NAME} --region ${REGION}"