#!/bin/bash

# ECS Task Failure Monitoring Stack Deployment Script
# Usage: ./deploy.sh <google-chat-webhook-url> [stack-name] [cluster-name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
DEFAULT_STACK_NAME="dev-an2d-ecs-monitoring-stack"
DEFAULT_ENV_PREFIX="dev-an2d"
REGION="ap-northeast-2"

# Check if webhook URL is provided
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Google Chat Webhook URL is required${NC}"
    echo "Usage: $0 <google-chat-webhook-url> [environment-prefix] [stack-name]"
    echo ""
    echo "Example:"
    echo "  $0 https://chat.googleapis.com/v1/spaces/XXX/messages?key=YYY&token=ZZZ"
    echo "  $0 https://chat.googleapis.com/v1/spaces/XXX/messages?key=YYY&token=ZZZ dev-an2d"
    echo "  $0 https://chat.googleapis.com/v1/spaces/XXX/messages?key=YYY&token=ZZZ stg-an2s my-stack"
    exit 1
fi

WEBHOOK_URL=$1
ENV_PREFIX=${2:-$DEFAULT_ENV_PREFIX}
STACK_NAME=${3:-"${ENV_PREFIX}-ecs-monitoring-stack"}

echo -e "${GREEN}=== ECS Task Failure Monitoring Stack Deployment ===${NC}"
echo ""
echo "Configuration:"
echo "  Stack Name: $STACK_NAME"
echo "  Environment Prefix: $ENV_PREFIX"
echo "  Monitoring: All ECS Clusters"
echo "  Region: $REGION"
echo "  Webhook URL: ${WEBHOOK_URL:0:50}..."
echo ""

# Validate template
echo -e "${YELLOW}Validating CloudFormation template...${NC}"
aws cloudformation validate-template \
    --template-body file://ecs-task-failure-monitoring.yaml \
    --region $REGION > /dev/null

echo -e "${GREEN}✓ Template validation successful${NC}"

# Deploy stack
echo -e "${YELLOW}Deploying CloudFormation stack...${NC}"
aws cloudformation deploy \
    --template-file ecs-task-failure-monitoring.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        GoogleChatWebhookUrl="$WEBHOOK_URL" \
        EnvironmentPrefix="$ENV_PREFIX" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Stack deployment successful!${NC}"
    echo ""
    
    # Get stack outputs
    echo "Stack Outputs:"
    aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].Outputs[*].[OutputKey, OutputValue]' \
        --output table
    
    echo ""
    echo -e "${GREEN}Deployment complete!${NC}"
    echo ""
    echo "The monitoring system is now active. It will send notifications to Google Chat when:"
    echo "  • ECS tasks fail with exit code != 0"
    echo "  • Essential containers exit unexpectedly"
    echo "  • Container pull errors occur"
    echo "  • Out of memory errors occur"
    echo "  • Container start failures occur"
    echo ""
    echo "To test the notification:"
    echo "  1. Deploy a task with intentional failure"
    echo "  2. Or manually send a test event to the SNS topic"
else
    echo -e "${RED}✗ Stack deployment failed${NC}"
    exit 1
fi