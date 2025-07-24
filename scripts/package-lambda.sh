#!/bin/bash

# Lambda Function Packaging Script
# Usage: ./scripts/package-lambda.sh [function-name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Default values
FUNCTION_NAME=${1:-"hello"}
LAMBDA_DIR="lambda"
PACKAGE_DIR="lambda_package"
REQUIREMENTS_FILE="${LAMBDA_DIR}/requirements.txt"

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
log_header "Lambda Function Packaging Script"
log_info "Function: ${FUNCTION_NAME}"
log_info "Lambda Directory: ${LAMBDA_DIR}"
log_info "Package Directory: ${PACKAGE_DIR}"
echo

# Check if lambda directory exists
if [ ! -d "${LAMBDA_DIR}" ]; then
    log_error "Lambda directory '${LAMBDA_DIR}' not found!"
    exit 1
fi

# Check if main function file exists
MAIN_FILE="${LAMBDA_DIR}/${FUNCTION_NAME}.py"
if [ ! -f "${MAIN_FILE}" ]; then
    log_error "Main function file '${MAIN_FILE}' not found!"
    exit 1
fi
log_success "Found main function file: ${MAIN_FILE}"

# Create package directory
log_header "Setting Up Package Directory"
if [ -d "${PACKAGE_DIR}" ]; then
    log_info "Cleaning existing package directory..."
    rm -rf ${PACKAGE_DIR}
fi

mkdir -p ${PACKAGE_DIR}
log_success "Package directory created: ${PACKAGE_DIR}"

# Copy Lambda function code
log_header "Copying Lambda Function Code"
log_info "Copying Python files from ${LAMBDA_DIR}..."
cp ${LAMBDA_DIR}/*.py ${PACKAGE_DIR}/
log_success "Lambda function code copied"

# Install dependencies if requirements.txt exists
if [ -f "${REQUIREMENTS_FILE}" ]; then
    log_header "Installing Python Dependencies"
    log_info "Found requirements.txt, installing dependencies..."
    
    # Check if we have any requirements
    if [ -s "${REQUIREMENTS_FILE}" ]; then
        log_info "Installing packages from ${REQUIREMENTS_FILE}..."
        pip3 install -r ${REQUIREMENTS_FILE} -t ${PACKAGE_DIR}/
        log_success "Dependencies installed to package directory"
        
        # Clean up unnecessary files
        log_info "Cleaning up unnecessary files..."
        find ${PACKAGE_DIR} -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
        find ${PACKAGE_DIR} -type f -name "*.pyc" -delete 2>/dev/null || true
        find ${PACKAGE_DIR} -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
        find ${PACKAGE_DIR} -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
        log_success "Cleanup completed"
    else
        log_warning "requirements.txt is empty, no dependencies to install"
    fi
else
    log_warning "No requirements.txt found, skipping dependency installation"
fi

# Create deployment package
log_header "Creating Deployment Package"
PACKAGE_FILE="${FUNCTION_NAME}-lambda.zip"

log_info "Creating ZIP package: ${PACKAGE_FILE}"
cd ${PACKAGE_DIR}
zip -r ../${PACKAGE_FILE} . -q
cd ..

# Check package size
PACKAGE_SIZE=$(du -h ${PACKAGE_FILE} | cut -f1)
PACKAGE_SIZE_BYTES=$(stat -f%z ${PACKAGE_FILE} 2>/dev/null || stat -c%s ${PACKAGE_FILE} 2>/dev/null)

log_success "Package created: ${PACKAGE_FILE} (${PACKAGE_SIZE})"

# Validate package size (AWS Lambda limit is 50MB zipped, 250MB unzipped)
MAX_SIZE_BYTES=$((50 * 1024 * 1024))  # 50MB in bytes
if [ ${PACKAGE_SIZE_BYTES} -gt ${MAX_SIZE_BYTES} ]; then
    log_error "Package size (${PACKAGE_SIZE}) exceeds AWS Lambda limit (50MB)!"
    log_error "Consider optimizing dependencies or using Lambda Layers"
    exit 1
fi

# Show package contents summary
log_header "Package Summary"
log_info "Package file: ${PACKAGE_FILE}"
log_info "Package size: ${PACKAGE_SIZE} (${PACKAGE_SIZE_BYTES} bytes)"
log_info "Package contents:"
unzip -l ${PACKAGE_FILE} | head -20
if [ $(unzip -l ${PACKAGE_FILE} | wc -l) -gt 25 ]; then
    echo "... (truncated, showing first 15 files)"
fi

# Validation
log_header "Package Validation"
log_info "Validating package structure..."

# Check if main handler exists
if unzip -l ${PACKAGE_FILE} | grep -q "${FUNCTION_NAME}.py"; then
    log_success "Main function file found in package"
else
    log_error "Main function file not found in package!"
    exit 1
fi

# Test import (basic syntax check)
log_info "Testing Python syntax..."
cd ${PACKAGE_DIR}
if python3 -m py_compile ${FUNCTION_NAME}.py; then
    log_success "Python syntax validation passed"
else
    log_error "Python syntax validation failed!"
    exit 1
fi
cd ..

# Clean up package directory (optional)
log_header "Cleanup"
read -p "Remove temporary package directory? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    rm -rf ${PACKAGE_DIR}
    log_success "Temporary package directory removed"
else
    log_info "Temporary package directory kept: ${PACKAGE_DIR}"
fi

echo
log_success "🎉 Lambda function packaging completed successfully!"
log_info "Package ready for deployment: ${PACKAGE_FILE}"
log_info ""
log_info "Next steps:"
log_info "  1. Test the package locally if needed"
log_info "  2. Deploy using CDK: npm run cdk deploy"
log_info "  3. Or upload directly to AWS Lambda console"