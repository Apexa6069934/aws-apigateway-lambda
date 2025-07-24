# AWS CDK Deployment Guide

This document provides comprehensive instructions for setting up and deploying the AWS CDK project with GitHub Actions.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Setup Instructions](#setup-instructions)
- [GitHub Actions Configuration](#github-actions-configuration)
- [Local Development](#local-development)
- [Deployment Workflows](#deployment-workflows)
- [Environment Management](#environment-management)
- [Troubleshooting](#troubleshooting)
- [Security Best Practices](#security-best-practices)

## Prerequisites

### Required Software

- **Node.js** (version 18 or later)
- **Python** (version 3.8, 3.9, or 3.10)
- **AWS CLI** (version 2.x)
- **AWS CDK** (version 2.x)
- **Git**

### Dependencies Note

This project uses `tr-cdk-lib` (Thomson Reuters CDK library), which is a private package. To use this project:

1. **For Thomson Reuters developers**: Ensure you have access to the internal npm registry
2. **For external developers**: You may need to replace `tr-cdk-lib` imports with standard AWS CDK constructs
3. **In CI/CD**: Ensure the GitHub Actions runner has access to private dependencies or adapt the code accordingly

### AWS Account Setup

1. **AWS Account**: Ensure you have an AWS account with appropriate permissions
2. **IAM Permissions**: Your user/role needs permissions for:
   - CloudFormation operations
   - IAM role creation and management
   - Lambda function management
   - API Gateway management
   - S3 bucket operations (for CDK assets)

### Installation Commands

```bash
# Install Node.js (using nvm)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 18
nvm use 18

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install AWS CDK
npm install -g aws-cdk

# Verify installations
node --version
python3 --version
aws --version
cdk --version
```

## Project Structure

```
aws-apigateway-lambda/
├── .github/
│   └── workflows/
│       ├── deploy.yml          # Main deployment workflow
│       ├── test.yml           # Testing workflow
│       └── deploy-dev.yml     # Development deployment
├── bin/
│   └── aws-apigateway-lambda.ts # CDK app entry point
├── lib/
│   └── aws-apigateway-lambda-stack.ts # CDK stack definition
├── lambda/
│   ├── hello.py               # Lambda function code
│   └── requirements.txt       # Python dependencies
├── scripts/
│   ├── deploy.sh             # Local deployment script
│   └── package-lambda.sh     # Lambda packaging script
├── test/
│   └── aws-apigateway-lambda.test.ts # CDK tests
├── cdk.json                  # CDK configuration
├── package.json              # Node.js dependencies
└── DEPLOYMENT.md             # This file
```

## Setup Instructions

### 1. Clone Repository

```bash
git clone <repository-url>
cd aws-apigateway-lambda
```

### 2. Install Dependencies

```bash
# Install Node.js dependencies
npm install

# Install Python dependencies (if any)
pip3 install -r lambda/requirements.txt
```

### 3. Configure AWS Credentials

#### Option A: AWS CLI Configuration
```bash
aws configure
```

#### Option B: Environment Variables
```bash
export AWS_ACCESS_KEY_ID=your-access-key-id
export AWS_SECRET_ACCESS_KEY=your-secret-access-key
export AWS_DEFAULT_REGION=us-east-1
```

#### Option C: IAM Roles (Recommended for EC2/Lambda)
Configure IAM roles with appropriate permissions.

### 4. CDK Bootstrap

Bootstrap CDK in your target AWS account/region (one-time setup):

```bash
cdk bootstrap aws://ACCOUNT-NUMBER/REGION
```

## GitHub Actions Configuration

### Required Secrets

Configure the following secrets in your GitHub repository:

#### Production Environment
- `AWS_ROLE_TO_ASSUME`: ARN of the IAM role for production deployments
- `AWS_REGION`: Target AWS region (e.g., us-east-1)
- `CDK_DEPLOY_ACCOUNT`: AWS account ID for production

#### Development Environment
- `AWS_DEV_ROLE_TO_ASSUME`: ARN of the IAM role for development deployments
- `CDK_DEV_DEPLOY_ACCOUNT`: AWS account ID for development

### OIDC Setup (Recommended)

For secure authentication without long-lived credentials:

1. **Create OIDC Identity Provider** in AWS IAM:
   - Provider URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`

2. **Create IAM Role** with trust policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:YOUR-ORG/YOUR-REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

3. **Attach Policies** to the role:
   - `AdministratorAccess` (for full deployment) or custom policies

### Environment Setup

Create GitHub environments:

1. **production**: For main/master branch deployments
2. **development**: For develop branch deployments
3. **staging**: For pull request testing

## Local Development

### Building the Project

```bash
# Compile TypeScript
npm run build

# Watch for changes
npm run watch
```

### Running Tests

```bash
# Run CDK unit tests
npm test

# Run Python Lambda tests (if configured)
cd lambda
python -m pytest
```

### Local Deployment

Use the provided script for local deployments:

```bash
# Deploy to development
./scripts/deploy.sh dev

# Deploy to production
./scripts/deploy.sh prod

# Package Lambda function separately
./scripts/package-lambda.sh hello
```

### CDK Commands

```bash
# Synthesize CloudFormation template
cdk synth

# Show differences
cdk diff

# Deploy stack
cdk deploy

# Destroy stack
cdk destroy
```

## Deployment Workflows

### 1. Main Deployment Workflow (`.github/workflows/deploy.yml`)

**Triggers:**
- Push to `main` or `master` branches
- Pull requests to `main` or `master`
- Manual workflow dispatch

**Features:**
- OIDC authentication with AWS
- Node.js and Python environment setup
- Dependency caching
- CDK synthesis and diff
- Automated deployment to production
- PR comments with CDK diff output

### 2. Testing Workflow (`.github/workflows/test.yml`)

**Triggers:**
- Push to any branch
- Pull requests

**Features:**
- Matrix testing across Python versions (3.8, 3.9, 3.10)
- TypeScript compilation and testing
- Python Lambda function testing
- Security scanning with npm audit
- Code coverage reporting

### 3. Development Deployment (`.github/workflows/deploy-dev.yml`)

**Triggers:**
- Push to `develop` branch
- Manual workflow dispatch

**Features:**
- Deployment to development environment
- Integration testing
- Development-specific configuration

## Environment Management

### Environment Variables

Set environment-specific variables in your CDK code:

```typescript
const environment = this.node.tryGetContext('environment') || 'dev';
const config = {
  dev: {
    instanceType: 't3.micro',
    minCapacity: 1,
    maxCapacity: 3
  },
  prod: {
    instanceType: 't3.small',
    minCapacity: 2,
    maxCapacity: 10
  }
};
```

### CDK Context

Use CDK context for environment-specific values:

```bash
# Deploy with specific context
cdk deploy --context environment=prod
```

## Troubleshooting

### Common Issues

#### 1. CDK Bootstrap Issues
```bash
# Error: This stack uses assets, so the toolkit stack must be deployed
cdk bootstrap aws://ACCOUNT/REGION
```

#### 2. Permission Denied
```bash
# Ensure your AWS credentials have sufficient permissions
aws sts get-caller-identity
```

#### 3. Lambda Package Too Large
```bash
# Use Lambda Layers for large dependencies
# Or optimize dependencies in requirements.txt
```

#### 4. GitHub Actions OIDC Issues
- Verify OIDC provider configuration
- Check IAM role trust policy
- Ensure correct repository and branch conditions

### Debugging Commands

```bash
# Check CDK context
cdk context

# View synthesized template
cdk synth --json

# Debug specific stack
cdk synth StackName --debug

# Check AWS credentials
aws sts get-caller-identity

# Validate CloudFormation template
aws cloudformation validate-template --template-body file://template.json
```

## Security Best Practices

### 1. IAM Permissions

- Use least privilege principle
- Create environment-specific roles
- Avoid using `AdministratorAccess` in production

### 2. Secrets Management

- Never commit AWS credentials to code
- Use GitHub Secrets for sensitive data
- Rotate credentials regularly
- Use OIDC instead of long-lived access keys

### 3. Network Security

- Configure VPC and security groups appropriately
- Use private subnets for sensitive resources
- Enable VPC Flow Logs

### 4. Code Security

- Run security scans in CI/CD
- Keep dependencies updated
- Use CDK security best practices

### 5. Monitoring and Logging

- Enable CloudTrail
- Configure CloudWatch monitoring
- Set up alerts for unusual activity

## Example Deployment Commands

### Development Deployment
```bash
git checkout develop
git push origin develop
# Automatically triggers development deployment
```

### Production Deployment
```bash
git checkout main
git merge develop
git push origin main
# Automatically triggers production deployment
```

### Manual Deployment
```bash
# Using GitHub CLI
gh workflow run deploy.yml --ref main

# Using local script
./scripts/deploy.sh prod api-endpoint-lambda
```

## Support and Contributing

For questions or issues:
1. Check this documentation
2. Review GitHub Actions logs
3. Check AWS CloudFormation events
4. Create an issue in the repository

When contributing:
1. Create feature branch from `develop`
2. Write tests for new functionality
3. Update documentation
4. Create pull request

## Additional Resources

- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [AWS API Gateway Documentation](https://docs.aws.amazon.com/apigateway/)