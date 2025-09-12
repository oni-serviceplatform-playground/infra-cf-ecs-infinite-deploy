#!/bin/bash

# Multi-region/account deployment script for ECS monitoring
# Deploys monitoring stack to multiple AWS accounts and regions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# AlertNow Webhook URL (same for all regions)
ALERTNOW_WEBHOOK_URL="https://alertnowitgr.opsnow.com/integration/standard/v1/9dfa2ece68ec5311f05bed1806b77546d703"

# Template file
TEMPLATE_FILE="ecs-task-failure-monitoring.yaml"

# Define deployment targets: profile, region, environment-prefix
declare -a DEPLOYMENTS=(
    "mea:me-central-1:mea-mc1p"
    "usa:us-west-1:usa-uw1p"
    "us2:us-east-1:us2-ue1p"
    "prd:ap-northeast-2:prd-an2p"
)

# Function to deploy stack
deploy_stack() {
    local PROFILE=$1
    local REGION=$2
    local ENV_PREFIX=$3
    local STACK_NAME="${ENV_PREFIX}-ecs-monitoring-stack"
    
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}Deploying to Profile: ${PROFILE}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Region: ${REGION}"
    echo -e "Environment: ${ENV_PREFIX}"
    echo -e "Stack: ${STACK_NAME}"
    
    # Check if profile exists and is logged in
    echo -e "\n${YELLOW}Checking AWS profile...${NC}"
    if ! AWS_PROFILE=$PROFILE aws sts get-caller-identity --region $REGION > /dev/null 2>&1; then
        echo -e "${RED}✗ Profile ${PROFILE} not logged in or doesn't exist${NC}"
        echo -e "${YELLOW}Attempting SSO login...${NC}"
        aws sso login --profile $PROFILE
        
        # Verify login worked
        if ! AWS_PROFILE=$PROFILE aws sts get-caller-identity --region $REGION > /dev/null 2>&1; then
            echo -e "${RED}✗ Failed to login to profile ${PROFILE}${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}✓ Profile ${PROFILE} is active${NC}"
    
    # Validate template
    echo -e "\n${YELLOW}Validating template...${NC}"
    if AWS_PROFILE=$PROFILE aws cloudformation validate-template \
        --template-body file://${TEMPLATE_FILE} \
        --region ${REGION} > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Template validation successful${NC}"
    else
        echo -e "${RED}✗ Template validation failed${NC}"
        return 1
    fi
    
    # Deploy stack
    echo -e "\n${YELLOW}Deploying CloudFormation stack...${NC}"
    if AWS_PROFILE=$PROFILE aws cloudformation deploy \
        --template-file ${TEMPLATE_FILE} \
        --stack-name ${STACK_NAME} \
        --parameter-overrides \
            ParameterKey=AlertNowWebhookUrl,ParameterValue="${ALERTNOW_WEBHOOK_URL}" \
            ParameterKey=EnvironmentPrefix,ParameterValue="${ENV_PREFIX}" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region ${REGION} \
        --no-fail-on-empty-changeset; then
        
        echo -e "${GREEN}✓ Stack ${STACK_NAME} deployed successfully${NC}"
        
        # Get Lambda function ARN
        LAMBDA_ARN=$(AWS_PROFILE=$PROFILE aws cloudformation describe-stacks \
            --stack-name ${STACK_NAME} \
            --region ${REGION} \
            --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionName`].OutputValue' \
            --output text 2>/dev/null)
        
        if [ ! -z "$LAMBDA_ARN" ]; then
            echo -e "${GREEN}Lambda Function: ${LAMBDA_ARN}${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}✗ Stack deployment failed${NC}"
        return 1
    fi
}

# Main execution
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Multi-Region ECS Monitoring Deployment${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${RED}Error: Template file $TEMPLATE_FILE not found!${NC}"
    exit 1
fi

# Track results
declare -a SUCCESS=()
declare -a FAILED=()

# Deploy to each target
for deployment in "${DEPLOYMENTS[@]}"; do
    IFS=':' read -r profile region env_prefix <<< "$deployment"
    
    if deploy_stack "$profile" "$region" "$env_prefix"; then
        SUCCESS+=("$profile ($region)")
    else
        FAILED+=("$profile ($region)")
    fi
done

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Summary${NC}"
echo -e "${GREEN}========================================${NC}"

if [ ${#SUCCESS[@]} -gt 0 ]; then
    echo -e "\n${GREEN}✓ Successful Deployments:${NC}"
    for item in "${SUCCESS[@]}"; do
        echo -e "  - $item"
    done
fi

if [ ${#FAILED[@]} -gt 0 ]; then
    echo -e "\n${RED}✗ Failed Deployments:${NC}"
    for item in "${FAILED[@]}"; do
        echo -e "  - $item"
    done
fi

echo -e "\n${YELLOW}Total: ${#SUCCESS[@]} successful, ${#FAILED[@]} failed${NC}"

# Cleanup instructions
echo -e "\n${YELLOW}To delete stacks, run:${NC}"
for deployment in "${DEPLOYMENTS[@]}"; do
    IFS=':' read -r profile region env_prefix <<< "$deployment"
    echo "AWS_PROFILE=$profile aws cloudformation delete-stack --stack-name ${env_prefix}-ecs-monitoring-stack --region $region"
done

exit 0