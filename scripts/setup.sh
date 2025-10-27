#!/bin/bash

# AWS VPC Automation - Initial Setup Script
# This script prepares the Ansible control machine for VPC deployment

set -e

echo "================================"
echo "AWS VPC Automation Setup"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on EC2
check_ec2() {
    print_status "Checking if running on EC2..."
    if curl -s --max-time 3 http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
        print_status "Running on EC2 instance"
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
        print_status "Instance ID: $INSTANCE_ID"
        print_status "Region: $REGION"
    else
        print_warning "Not running on EC2 or metadata service unavailable"
    fi
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Python
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version)
        print_status "Python found: $PYTHON_VERSION"
    else
        print_error "Python 3 is required but not installed"
        exit 1
    fi
    
    # Check pip
    if command -v pip3 &> /dev/null; then
        print_status "pip3 is available"
    else
        print_error "pip3 is required but not found"
        exit 1
    fi
    
    # Check git
    if command -v git &> /dev/null; then
        print_status "Git is available"
    else
        print_error "Git is required but not installed"
        exit 1
    fi
}

# Install Ansible if not present
install_ansible() {
    if command -v ansible &> /dev/null; then
        ANSIBLE_VERSION=$(ansible --version | head -n1)
        print_status "Ansible already installed: $ANSIBLE_VERSION"
    else
        print_status "Installing Ansible..."
        pip3 install --user ansible
        
        # Add to PATH if not already there
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
            export PATH="$HOME/.local/bin:$PATH"
        fi
        
        print_status "Ansible installed successfully"
    fi
}

# Install AWS CLI if not present
install_aws_cli() {
    if command -v aws &> /dev/null; then
        AWS_VERSION=$(aws --version)
        print_status "AWS CLI already installed: $AWS_VERSION"
    else
        print_status "Installing AWS CLI..."
        
        # Download and install AWS CLI v2
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        
        if command -v unzip &> /dev/null; then
            unzip awscliv2.zip
        else
            print_status "Installing unzip..."
            sudo yum install -y unzip || sudo apt-get install -y unzip
            unzip awscliv2.zip
        fi
        
        sudo ./aws/install
        rm -rf awscliv2.zip aws/
        print_status "AWS CLI installed successfully"
    fi
}

# Install Python dependencies
install_python_deps() {
    print_status "Installing Python dependencies..."
    
    # Create requirements.txt if it doesn't exist
    cat > requirements.txt << 'EOF'
boto3>=1.26.0
botocore>=1.29.0
ansible>=6.0.0
PyYAML>=5.4.0
jinja2>=3.0.0
cryptography>=3.4.0
EOF
    
    pip3 install --user -r requirements.txt
    print_status "Python dependencies installed"
}

# Configure AWS credentials
configure_aws() {
    print_status "Checking AWS credentials..."
    
    if aws sts get-caller-identity &> /dev/null; then
        print_status "AWS credentials are configured"
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
        print_status "Account ID: $ACCOUNT_ID"
        print_status "User/Role: $USER_ARN"
    else
        print_warning "AWS credentials not configured"
        print_status "Please run 'aws configure' to set up your credentials"
        print_status "Or attach an IAM role to this EC2 instance"
        
        read -p "Do you want to configure AWS credentials now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            aws configure
        fi
    fi
}

# Test Ansible installation
test_ansible() {
    print_status "Testing Ansible installation..."
    
    # Test basic ansible command
    if ansible localhost -m ping; then
        print_status "Ansible is working correctly"
    else
        print_error "Ansible test failed"
        exit 1
    fi
    
    # Test AWS modules
    if ansible localhost -m ec2_vpc_info -a "region=us-east-1" &> /dev/null; then
        print_status "Ansible AWS modules are working"
    else
        print_warning "Ansible AWS modules may need additional configuration"
    fi
}

# Generate SSH key pair if not exists
setup_ssh_keys() {
    print_status "Setting up SSH keys..."
    
    if [ ! -f ~/.ssh/id_rsa ]; then
        print_status "Generating SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
        print_status "SSH key pair generated"
    else
        print_status "SSH key pair already exists"
    fi
    
    # Set proper permissions
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/id_rsa
    chmod 644 ~/.ssh/id_rsa.pub
}

# Create Ansible configuration
create_ansible_config() {
    print_status "Creating Ansible configuration..."
    
    cat > ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
inventory = inventory/hosts
roles_path = roles
stdout_callback = yaml
bin_ansible_callbacks = True
gathering = explicit
retry_files_enabled = False

[inventory]
enable_plugins = aws_ec2, host_list, script, auto, yaml, ini, toml

[ssh_connection]
ssh_args = -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
pipelining = True
EOF
    
    print_status "Ansible configuration created"
}

# Display next steps
show_next_steps() {
    echo
    print_status "Setup completed successfully!"
    echo
    echo "================================"
    echo "NEXT STEPS"
    echo "================================"
    echo
    echo "1. Configure your deployment variables:"
    echo "   - Edit inventory/group_vars/all.yml"
    echo "   - Edit inventory/group_vars/aws.yml"
    echo
    echo "2. Deploy the infrastructure:"
    echo "   - Full deployment: ./scripts/deploy.sh"
    echo "   - Or run manually: ansible-playbook -i inventory/hosts site.yml"
    echo
    echo "3. Validate the deployment:"
    echo "   - ansible-playbook -i inventory/hosts playbooks/validate.yml"
    echo
    echo "4. Connect to bastion host:"
    echo "   - Use generated script: ./connect-bastion.sh"
    echo
    echo "================================"
    echo "AWS VPC Automation Ready!"
    echo "================================"
}

# Main execution
main() {
    print_status "Starting AWS VPC Automation setup..."
    
    check_ec2
    check_prerequisites
    install_ansible
    install_aws_cli
    install_python_deps
    configure_aws
    test_ansible
    setup_ssh_keys
    create_ansible_config
    show_next_steps
}

# Run main function
main "$@"