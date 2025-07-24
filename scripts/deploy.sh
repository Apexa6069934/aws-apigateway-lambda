#!/bin/bash

# AWS CDK Deployment Script with Colored Output
# Usage: ./scripts/deploy.sh [environment] [stack-name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=${1:-"dev"}
STACK_NAME=${2:-"api-endpoint-lambda"}
AWS_REGION=${AWS_REGION:-"us-east-1"}

# Functions for colored output
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}==== $1 ====${NC}"
}

# Print banner
echo -e "${CYAN}"
cat << "EOF"
  ____  ____  _  __   ____             _            
 / ___||  _ \| |/ /  |  _ \  ___ _ __ | | ___  _   _ 
| |    | | | | ' /   | | | |/ _ \ '_ \| |/ _ \| | | |
| |___ | |_| | . \   | |_| |  __/ |_) | | (_) | |_| |
 \____||____/|_|\_\  |____/ \___| .__/|_|\___/ \__, |
                                |_|            |___/ 
EOF
echo -e "${NC}"

log_header "AWS CDK Deployment Script"
log_info "Environment: ${ENVIRONMENT}"
log_info "Stack Name: ${STACK_NAME}"
log_info "AWS Region: ${AWS_REGION}"
echo

# Check prerequisites
log_header "Checking Prerequisites"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI is not installed. Please install it first."
    exit 1
fi
log_success "AWS CLI found"

# Check if CDK is installed
if ! command -v cdk &> /dev/null; then
    log_warning "CDK not found. Installing globally..."
    npm install -g aws-cdk
    log_success "CDK installed"
else
    log_success "CDK found"
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    log_error "Node.js is not installed. Please install it first."
    exit 1
fi
log_success "Node.js found ($(node --version))"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    log_error "Python 3 is not installed. Please install it first."
    exit 1
fi
log_success "Python 3 found ($(python3 --version))"

# Check AWS credentials
log_info "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
log_success "AWS credentials configured (Account: ${AWS_ACCOUNT})"

echo

# Install dependencies
log_header "Installing Dependencies"
log_info "Installing Node.js dependencies..."
npm ci
log_success "Node.js dependencies installed"

log_info "Installing Python dependencies..."
if [ -f "lambda/requirements.txt" ]; then
    pip3 install -r lambda/requirements.txt
    log_success "Python dependencies installed"
else
    log_warning "No lambda/requirements.txt found, skipping Python dependencies"
fi

echo

# Build the application
log_header "Building Application"
log_info "Compiling TypeScript..."
npm run build
log_success "TypeScript compiled successfully"

echo

# Package Lambda function
log_header "Packaging Lambda Function"
if [ -f "scripts/package-lambda.sh" ]; then
    log_info "Running Lambda packaging script..."
    bash scripts/package-lambda.sh
    log_success "Lambda function packaged"
else
    log_info "No custom Lambda packaging script found, using CDK default packaging"
fi

echo

# CDK Bootstrap (if needed)
log_header "CDK Bootstrap Check"
log_info "Checking if CDK bootstrap is needed..."
if ! aws cloudformation describe-stacks --stack-name CDKToolkit --region ${AWS_REGION} &> /dev/null; then
    log_warning "CDKToolkit stack not found. Running CDK bootstrap..."
    cdk bootstrap aws://${AWS_ACCOUNT}/${AWS_REGION}
    log_success "CDK bootstrap completed"
else
    log_success "CDK already bootstrapped"
fi

echo

# Synthesize CloudFormation template
log_header "Synthesizing CloudFormation Template"
log_info "Running CDK synth..."
cdk synth ${STACK_NAME}
log_success "CloudFormation template synthesized"

echo

# Show diff (optional)
log_header "Checking Deployment Diff"
log_info "Showing changes to be deployed..."
cdk diff ${STACK_NAME} || log_info "No changes detected or first deployment"

echo

# Deploy confirmation
log_header "Deployment Confirmation"
echo -e "${YELLOW}You are about to deploy the following:${NC}"
echo -e "  Stack Name: ${CYAN}${STACK_NAME}${NC}"
echo -e "  Environment: ${CYAN}${ENVIRONMENT}${NC}"
echo -e "  AWS Account: ${CYAN}${AWS_ACCOUNT}${NC}"
echo -e "  AWS Region: ${CYAN}${AWS_REGION}${NC}"
echo

read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Deployment cancelled by user"
    exit 0
fi

echo

# Deploy the stack
log_header "Deploying CDK Stack"
log_info "Starting deployment..."
export CDK_DEPLOY_ACCOUNT=${AWS_ACCOUNT}
export CDK_DEPLOY_REGION=${AWS_REGION}

if cdk deploy ${STACK_NAME} --require-approval never --context environment=${ENVIRONMENT}; then
    log_success "Deployment completed successfully!"
    
    echo
    log_header "Deployment Summary"
    log_info "Stack: ${STACK_NAME}"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Region: ${AWS_REGION}"
    log_info "Account: ${AWS_ACCOUNT}"
    
    # Try to get stack outputs
    log_info "Fetching stack outputs..."
    if aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${AWS_REGION} --query 'Stacks[0].Outputs' --output table 2>/dev/null; then
        log_success "Stack outputs displayed above"
    else
        log_warning "No stack outputs found or unable to fetch"
    fi
    
    echo
    log_success "🎉 Deployment completed successfully!"
else
    log_error "Deployment failed!"
    exit 1
fi