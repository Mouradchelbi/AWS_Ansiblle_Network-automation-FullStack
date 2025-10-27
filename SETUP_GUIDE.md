# AWS VPC Full-Stack Automation Setup Guide

## Overview
This guide explains how to set up and deploy the AWS VPC full-stack automation solution for your AWS management team. The solution provides centralized infrastructure management using Ansible.

## Prerequisites

### 1. EC2 Ansible Control Machine
- **Instance Type**: t3.small or larger (recommended)
- **OS**: Amazon Linux 2 or Ubuntu 20.04+
- **Storage**: At least 20GB
- **IAM Role**: Attach IAM role with appropriate permissions (see IAM section below)

### 2. Required IAM Permissions
The Ansible control machine needs an IAM role with these permissions:

#### EC2 Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "vpc:*",
                "iam:PassRole",
                "iam:ListInstanceProfiles"
            ],
            "Resource": "*"
        }
    ]
}
```

#### Additional Service Permissions
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:*",
                "cloudwatch:*",
                "sns:*",
                "iam:CreateRole",
                "iam:CreateInstanceProfile",
                "iam:AttachRolePolicy",
                "iam:AddRoleToInstanceProfile"
            ],
            "Resource": "*"
        }
    ]
}
```

## Setup Process

### Step 1: Launch EC2 Control Machine

1. **Launch EC2 Instance**:
   ```bash
   # Example using AWS CLI
   aws ec2 run-instances \
       --image-id ami-0c02fb55956c7d316 \
       --count 1 \
       --instance-type t3.small \
       --key-name your-key-pair \
       --security-groups default \
       --iam-instance-profile Name=AnsibleControlRole
   ```

2. **Connect to Instance**:
   ```bash
   ssh -i your-key.pem ec2-user@<instance-ip>
   ```

### Step 2: Clone Repository

1. **Install Git** (if not present):
   ```bash
   sudo yum update -y
   sudo yum install -y git
   ```

2. **Clone the Repository**:
   ```bash
   git clone <your-github-repo-url>
   cd VPC_Automation
   ```

### Step 3: Run Initial Setup

Execute the setup script to install all dependencies:

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

**What the setup script does**:
- ✅ Checks if running on EC2
- ✅ Installs Python 3 and pip
- ✅ Installs Ansible (latest version)
- ✅ Installs AWS CLI v2
- ✅ Installs required Python packages (boto3, botocore)
- ✅ Configures Ansible settings
- ✅ Sets up SSH keys
- ✅ Tests AWS connectivity
- ✅ Validates Ansible installation

### Step 4: Configure Variables

#### 4.1 Edit Global Variables
```bash
nano inventory/group_vars/all.yml
```

**Key configurations to modify**:
```yaml
# Environment configuration
env_name: "production"  # or "staging", "dev"
project_name: "vpc-automation"
owner: "aws-management-team"

# AWS Region - CHANGE THIS
aws_region: "us-west-2"  # Change to your preferred region

# VPC Configuration - MODIFY AS NEEDED
vpc_cidr: "10.0.0.0/16"

# Subnet Configuration - ADJUST CIDRS
public_subnets:
  - cidr: "10.0.1.0/24"
    az: "us-west-2a"
    name: "{{ vpc_name }}-public-subnet-1"
  - cidr: "10.0.2.0/24"  
    az: "us-west-2b"
    name: "{{ vpc_name }}-public-subnet-2"

# Security - UPDATE WITH YOUR IPs
ssh_allowed_ips:
  - "203.0.113.0/24"  # Replace with your office IP range

# Notifications - UPDATE EMAIL
notification_email: "your-aws-team@company.com"
```

#### 4.2 Edit AWS-Specific Variables
```bash
nano inventory/group_vars/aws.yml
```

**Update if needed**:
```yaml
# EC2 Key Pair path
ec2_keypair:
  name: "{{ bastion_key_pair }}"
  public_key_path: "~/.ssh/id_rsa.pub"

# AMI ID - update if needed for your region
bastion_ami_id: "ami-0c02fb55956c7d316"  # Amazon Linux 2
```

### Step 5: Deploy Infrastructure

#### 5.1 Full Deployment
```bash
# Interactive deployment (with confirmation)
./scripts/deploy.sh

# Or automated deployment
./scripts/deploy.sh -y
```

#### 5.2 Partial Deployments
```bash
# Deploy only VPC and networking
./scripts/deploy.sh -m vpc-only -y

# Deploy only security components
./scripts/deploy.sh -m security-only -y

# Deploy only bastion host
./scripts/deploy.sh -m bastion-only -y
```

#### 5.3 Dry Run (Test Mode)
```bash
# See what would be deployed without making changes
./scripts/deploy.sh -d
```

### Step 6: Validate Deployment

Run the validation playbook to ensure everything is working:

```bash
ansible-playbook -i inventory/hosts playbooks/validate.yml
```

**The validation checks**:
- ✅ VPC exists and is available
- ✅ Internet Gateway is attached
- ✅ NAT Gateway is running (if enabled)
- ✅ All subnets are available
- ✅ Security groups are configured
- ✅ Bastion host is running and accessible
- ✅ Route tables are configured correctly
- ✅ VPC Flow Logs are active (if enabled)

### Step 7: Connect to Bastion Host

After successful deployment, you'll have several ways to connect:

#### 7.1 Using Generated Script
```bash
./connect-bastion.sh
```

#### 7.2 Direct SSH
```bash
ssh -i vpc-automation-production-keypair.pem ec2-user@<bastion-public-ip>
```

#### 7.3 SSH Config Method
Add the generated SSH config to your `~/.ssh/config`:
```bash
cat ssh-config >> ~/.ssh/config
ssh vpc-automation-production-bastion
```

## Deployment Components

### What Gets Created

#### 1. VPC Infrastructure
- **VPC**: Custom VPC with configurable CIDR
- **Internet Gateway**: For public internet access
- **NAT Gateway**: For private subnet outbound access
- **Elastic IP**: Dedicated IP for NAT Gateway

#### 2. Subnets
- **Public Subnets**: 2 subnets across AZs for load balancers, bastion
- **Private Subnets**: 2 subnets across AZs for application servers
- **Database Subnets**: 2 subnets across AZs for databases

#### 3. Route Tables
- **Public Route Table**: Routes traffic to Internet Gateway
- **Private Route Table**: Routes traffic to NAT Gateway

#### 4. Security Groups
- **Bastion SG**: SSH access from allowed IPs
- **Web SG**: HTTP/HTTPS from ALB, SSH from bastion
- **App SG**: App ports from web tier, SSH from bastion
- **DB SG**: Database ports from app tier, SSH from bastion
- **ALB SG**: HTTP/HTTPS from internet

#### 5. Network ACLs
- **Public NACL**: Allow web traffic and SSH
- **Private NACL**: Allow internal traffic and outbound
- **Database NACL**: Allow database traffic from VPC

#### 6. Bastion Host
- **EC2 Instance**: Hardened Amazon Linux 2
- **Elastic IP**: Dedicated public IP
- **Security Features**: Fail2Ban, SSH hardening, CloudWatch agent
- **IAM Role**: For Systems Manager and CloudWatch

#### 7. Monitoring & Logging
- **VPC Flow Logs**: Network traffic logging
- **CloudWatch Alarms**: CPU monitoring for bastion
- **SNS Notifications**: Alert notifications

## Project Structure Explained

```
VPC_Automation/
├── README.md                    # Main documentation
├── site.yml                     # Main deployment playbook
├── ansible.cfg                  # Ansible configuration
├── requirements.txt             # Python dependencies
├── inventory/
│   ├── hosts                   # Inventory file
│   └── group_vars/
│       ├── all.yml             # Global variables
│       └── aws.yml             # AWS-specific variables
├── roles/
│   ├── common/                 # Common setup tasks
│   ├── vpc/                    # VPC and networking
│   ├── security/               # Security groups and NACLs
│   └── bastion/                # Bastion host deployment
├── playbooks/
│   ├── deploy.yml              # Deployment playbook
│   ├── destroy.yml             # Cleanup playbook
│   └── validate.yml            # Validation playbook
└── scripts/
    ├── setup.sh                # Initial setup script
    └── deploy.sh               # Deployment script
```

## Usage Examples

### Deploy to Different Environments

#### Production Deployment
```bash
# Edit variables for production
nano inventory/group_vars/all.yml
# Set: env_name: "production"

./scripts/deploy.sh -y
```

#### Staging Deployment
```bash
# Create staging variables
cp inventory/group_vars/all.yml inventory/group_vars/staging.yml
# Edit staging-specific values

# Deploy with staging vars
ansible-playbook -i inventory/hosts site.yml -e "@inventory/group_vars/staging.yml"
```

### Deploy to Multiple Regions

1. **Create region-specific variable files**:
   ```bash
   cp inventory/group_vars/all.yml inventory/group_vars/us-west-2.yml
   cp inventory/group_vars/all.yml inventory/group_vars/eu-west-1.yml
   ```

2. **Deploy to specific region**:
   ```bash
   ansible-playbook -i inventory/hosts site.yml -e "@inventory/group_vars/us-west-2.yml"
   ```

### Cleanup/Destroy Infrastructure

**⚠️ WARNING**: This permanently deletes all resources!

```bash
# With confirmation prompt
ansible-playbook -i inventory/hosts playbooks/destroy.yml

# Force cleanup without confirmation
ansible-playbook -i inventory/hosts playbooks/destroy.yml -e destroy_mode=force
```

## Troubleshooting

### Common Issues

#### 1. AWS Credentials Error
```bash
# Check AWS configuration
aws sts get-caller-identity

# Reconfigure if needed
aws configure
```

#### 2. Ansible Module Not Found
```bash
# Reinstall Ansible collections
ansible-galaxy collection install amazon.aws --force
ansible-galaxy collection install community.aws --force
```

#### 3. SSH Connection Issues
```bash
# Check security group rules
# Ensure your IP is in ssh_allowed_ips variable
# Verify key pair permissions
chmod 600 *.pem
```

#### 4. Region Availability Issues
Some AWS services may not be available in all regions. Check:
- VPC availability
- NAT Gateway support
- AMI ID for the region

### Getting Help

1. **Check Ansible logs**: `tail -f ansible.log`
2. **Run validation**: `ansible-playbook -i inventory/hosts playbooks/validate.yml`
3. **Verbose mode**: Add `-v` or `-vvv` to ansible commands
4. **Check AWS console**: Verify resources in AWS console

## Security Best Practices

### Implemented Security Features
- ✅ Network ACLs for layer 4 protection
- ✅ Security groups with least privilege
- ✅ Private subnets for sensitive resources
- ✅ Bastion host with hardened configuration
- ✅ SSH key-based authentication only
- ✅ VPC Flow Logs for monitoring
- ✅ CloudWatch monitoring and alerting

### Additional Recommendations
1. **Rotate SSH keys regularly**
2. **Use Systems Manager Session Manager** instead of SSH when possible
3. **Implement VPN** for enhanced security
4. **Enable GuardDuty** for threat detection
5. **Use AWS Config** for compliance monitoring

## Cost Optimization

### Estimated Monthly Costs (us-east-1)
- **VPC, Subnets, IGW**: Free
- **NAT Gateway**: ~$45/month
- **Bastion Host (t3.micro)**: ~$9/month
- **Elastic IPs**: ~$7/month (2 IPs)
- **VPC Flow Logs**: ~$3/month (moderate traffic)

**Total**: ~$64/month

### Cost Savings Tips
1. **Stop bastion when not needed**: Use start/stop scripts
2. **Use smaller instance types**: t3.nano for light usage
3. **Disable NAT Gateway**: If private instances don't need internet
4. **Use VPC endpoints**: For AWS service access from private subnets

This setup provides you with a production-ready, secure, and scalable AWS VPC infrastructure managed through code, perfect for your centralized AWS management needs!