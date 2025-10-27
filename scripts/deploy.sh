#!/bin/bash

# AWS VPC Automation - Deployment Script
# This script deploys the complete VPC infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Default values
DEPLOYMENT_MODE="full"
SKIP_CONFIRMATION=false
DRY_RUN=false
TAGS=""
VERBOSE=false

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -m, --mode MODE          Deployment mode (full|vpc-only|security-only|bastion-only)"
    echo "  -y, --yes               Skip confirmation prompts"
    echo "  -d, --dry-run           Perform a dry run (check mode)"
    echo "  -t, --tags TAGS         Ansible tags to run (comma-separated)"
    echo "  -v, --verbose           Verbose output"
    echo "  -h, --help              Show this help message"
    echo
    echo "Examples:"
    echo "  $0                      # Full deployment with confirmation"
    echo "  $0 -m vpc-only -y       # Deploy only VPC without confirmation"
    echo "  $0 -d                   # Dry run to check what would be deployed"
    echo "  $0 -t vpc,security      # Deploy only VPC and security components"
    echo
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            DEPLOYMENT_MODE="$2"
            shift 2
            ;;
        -y|--yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -t|--tags)
            TAGS="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate deployment mode
validate_mode() {
    case $DEPLOYMENT_MODE in
        full|vpc-only|security-only|bastion-only)
            ;;
        *)
            print_error "Invalid deployment mode: $DEPLOYMENT_MODE"
            print_error "Valid modes: full, vpc-only, security-only, bastion-only"
            exit 1
            ;;
    esac
}

# Pre-flight checks
pre_flight_checks() {
    print_header "================================"
    print_header "Pre-flight Checks"
    print_header "================================"
    
    # Check if we're in the right directory
    if [ ! -f "site.yml" ] || [ ! -d "roles" ]; then
        print_error "Please run this script from the VPC_Automation directory"
        exit 1
    fi
    
    # Check Ansible installation
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible is not installed. Please run ./scripts/setup.sh first"
        exit 1
    fi
    
    # Check AWS credentials
    print_info "Checking AWS credentials..."
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure'"
        exit 1
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    REGION=$(aws configure get region || echo "us-east-1")
    
    print_info "AWS Account ID: $ACCOUNT_ID"
    print_info "User/Role: $USER_ARN"
    print_info "Region: $REGION"
    
    # Check required variables
    print_info "Validating configuration files..."
    if [ ! -f "inventory/group_vars/all.yml" ]; then
        print_error "Configuration file missing: inventory/group_vars/all.yml"
        exit 1
    fi
    
    # Test Ansible syntax
    print_info "Checking Ansible playbook syntax..."
    if ! ansible-playbook --syntax-check site.yml; then
        print_error "Ansible playbook syntax check failed"
        exit 1
    fi
    
    print_info "Pre-flight checks passed!"
}

# Display deployment summary
show_deployment_summary() {
    print_header "================================"
    print_header "Deployment Summary"
    print_header "================================"
    
    print_info "Deployment Mode: $DEPLOYMENT_MODE"
    print_info "AWS Account: $ACCOUNT_ID"
    print_info "Region: $REGION"
    print_info "Dry Run: $([ "$DRY_RUN" = true ] && echo "Yes" || echo "No")"
    
    if [ -n "$TAGS" ]; then
        print_info "Tags: $TAGS"
    fi
    
    echo
    case $DEPLOYMENT_MODE in
        full)
            echo "This will deploy:"
            echo "  ✓ VPC and networking components"
            echo "  ✓ Security groups and NACLs"
            echo "  ✓ Bastion host"
            ;;
        vpc-only)
            echo "This will deploy:"
            echo "  ✓ VPC and networking components only"
            ;;
        security-only)
            echo "This will deploy:"
            echo "  ✓ Security groups and NACLs only"
            ;;
        bastion-only)
            echo "This will deploy:"
            echo "  ✓ Bastion host only"
            ;;
    esac
    echo
}

# Confirmation prompt
get_confirmation() {
    if [ "$SKIP_CONFIRMATION" = true ]; then
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "This is a dry run - no actual changes will be made"
        return 0
    fi
    
    echo "This deployment will create AWS resources that may incur charges."
    read -p "Do you want to proceed? (yes/no): " -r
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Deployment cancelled by user"
        exit 0
    fi
}

# Build ansible command
build_ansible_command() {
    local cmd="ansible-playbook -i inventory/hosts"
    
    if [ "$VERBOSE" = true ]; then
        cmd="$cmd -v"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        cmd="$cmd --check --diff"
    fi
    
    if [ -n "$TAGS" ]; then
        cmd="$cmd --tags $TAGS"
    fi
    
    # Add extra vars for deployment mode
    cmd="$cmd -e deploy_mode=$DEPLOYMENT_MODE"
    
    echo "$cmd"
}

# Execute deployment
execute_deployment() {
    print_header "================================"
    print_header "Starting Deployment"
    print_header "================================"
    
    local start_time=$(date +%s)
    local ansible_cmd=$(build_ansible_command)
    
    print_info "Running: $ansible_cmd site.yml"
    echo
    
    # Execute the ansible command
    if $ansible_cmd site.yml; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        print_header "================================"
        print_header "Deployment Completed Successfully"
        print_header "================================"
        print_info "Duration: ${duration} seconds"
        
        if [ "$DRY_RUN" != true ]; then
            print_info "Next steps:"
            echo "  1. Run validation: ansible-playbook -i inventory/hosts playbooks/validate.yml"
            echo "  2. Check deployment report in current directory"
            echo "  3. Connect to bastion using ./connect-bastion.sh"
        fi
    else
        print_error "Deployment failed!"
        print_error "Check the Ansible output above for details"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    print_info "Cleaning up temporary files..."
    # Add any cleanup tasks here
}

# Trap for cleanup on exit
trap cleanup EXIT

# Main execution
main() {
    validate_mode
    pre_flight_checks
    show_deployment_summary
    get_confirmation
    execute_deployment
}

# Run main function
main "$@"