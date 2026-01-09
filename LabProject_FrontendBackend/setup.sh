#!/bin/bash
# Setup script for Lab Project - Run this first!

set -e

echo "================================================"
echo "Lab Project Setup Script"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "ℹ $1"
}

# Check prerequisites
echo "Checking prerequisites..."
echo ""

# Check Terraform
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version | head -n1)
    print_success "Terraform is installed: $TERRAFORM_VERSION"
else
    print_error "Terraform is not installed"
    echo "Install from: https://www.terraform.io/downloads"
    exit 1
fi

# Check Ansible
if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -n1)
    print_success "Ansible is installed: $ANSIBLE_VERSION"
else
    print_error "Ansible is not installed"
    echo "Install with: pip install ansible"
    exit 1
fi

# Check AWS CLI
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version)
    print_success "AWS CLI is installed: $AWS_VERSION"
else
    print_error "AWS CLI is not installed"
    echo "Install from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check jq (useful for testing)
if command -v jq &> /dev/null; then
    print_success "jq is installed"
else
    print_warning "jq is not installed (optional, but recommended for testing)"
    echo "Install with: sudo apt-get install jq (Ubuntu) or brew install jq (Mac)"
fi

echo ""
echo "Checking AWS configuration..."
echo ""

# Check AWS credentials
if aws sts get-caller-identity &> /dev/null; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    print_success "AWS credentials configured"
    print_info "Account: $AWS_ACCOUNT"
    print_info "User: $AWS_USER"
else
    print_error "AWS credentials not configured"
    echo "Run: aws configure"
    exit 1
fi

echo ""
echo "Checking SSH keys..."
echo ""

# Check SSH keys
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
SSH_PUB_KEY_PATH="$HOME/.ssh/id_rsa.pub"

if [ -f "$SSH_KEY_PATH" ] && [ -f "$SSH_PUB_KEY_PATH" ]; then
    print_success "SSH key pair found at $SSH_KEY_PATH"
    
    # Check permissions
    KEY_PERMS=$(stat -c %a "$SSH_KEY_PATH" 2>/dev/null || stat -f %A "$SSH_KEY_PATH" 2>/dev/null)
    if [ "$KEY_PERMS" = "600" ]; then
        print_success "SSH key permissions are correct (600)"
    else
        print_warning "SSH key permissions are $KEY_PERMS (should be 600)"
        echo "Fixing permissions..."
        chmod 600 "$SSH_KEY_PATH"
        print_success "Fixed SSH key permissions"
    fi
else
    print_warning "SSH key pair not found"
    echo ""
    read -p "Would you like to generate an SSH key pair now? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N ""
        print_success "SSH key pair generated"
    else
        print_error "SSH key pair required. Generate manually with:"
        echo "ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N \"\""
        exit 1
    fi
fi

echo ""
echo "Setting up project..."
echo ""

# Create terraform.tfvars if it doesn't exist
if [ ! -f "terraform.tfvars" ]; then
    print_info "Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    print_success "Created terraform.tfvars"
    print_warning "Please review and customize terraform.tfvars if needed"
else
    print_success "terraform.tfvars already exists"
fi

# Initialize Terraform
echo ""
echo "Initializing Terraform..."
if terraform init; then
    print_success "Terraform initialized successfully"
else
    print_error "Terraform initialization failed"
    exit 1
fi

# Validate Terraform configuration
echo ""
echo "Validating Terraform configuration..."
if terraform validate; then
    print_success "Terraform configuration is valid"
else
    print_error "Terraform configuration validation failed"
    exit 1
fi

echo ""
echo "================================================"
print_success "Setup completed successfully!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Review terraform.tfvars (optional)"
echo "2. Run: terraform plan (to preview changes)"
echo "3. Run: terraform apply -auto-approve (to deploy)"
echo "4. Run: ./test.sh (to test the deployment)"
echo ""
echo "To deploy everything now, run:"
echo "  terraform apply -auto-approve"
echo ""
echo "For detailed instructions, see:"
echo "  - README.md"
echo "  - DEPLOYMENT.md"
echo "  - CHECKLIST.md"
echo ""
