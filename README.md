# AWS VPC Full Stack Automation

This Ansible project provides complete automation for deploying AWS VPC infrastructure for central management by the AWS management team.

## Architecture Overview

The automation creates a production-ready VPC with:
- **VPC**: Custom VPC with configurable CIDR
- **Internet Gateway**: For public internet access
- **NAT Gateway**: For private subnet internet access
- **Subnets**: 
  - Public subnets (for bastion, load balancers)
  - Private subnets (for application servers, databases)
- **Route Tables**: Proper routing configuration
- **Network ACLs**: Network-level security
- **Security Groups**: Instance-level security
- **Bastion Host**: Secure access to private resources

## Prerequisites

### 1. Ansible Control Machine (EC2 instance)
- **Instance Type**: t3.small or larger (recommended)
- **OS**: Amazon Linux 2 or Ubuntu 20.04+
- **Storage**: Minimum 20GB EBS volume
- **Ansible**: Version 6.0+ (auto-installed by setup script)
- **Python**: 3.8+ with pip
- **AWS CLI**: Version 2.x (auto-installed by setup script)
- **Libraries**: boto3, botocore (auto-installed)

### 2. Required IAM Permissions
The EC2 instance (Ansible Control Machine) needs an IAM role with the following AWS managed policies:

1. Required AWS Managed Policies:
   - `AmazonEC2FullAccess`
   - `AmazonVPCFullAccess`
   - `CloudWatchFullAccess`
   - `IAMFullAccess`
   - `AmazonSNSFullAccess`

Alternatively, you can use a custom policy with these permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "vpc:*",
                "elasticloadbalancing:*",
                "cloudwatch:*",
                "autoscaling:*",
                "iam:PassRole",
                "iam:CreateRole",
                "iam:CreateInstanceProfile",
                "iam:AttachRolePolicy",
                "iam:AddRoleToInstanceProfile",
                "iam:ListInstanceProfiles",
                "logs:*",
                "cloudwatch:*",
                "sns:*"
            ],
            "Resource": "*"
        }
    ]
}
```

### 3. Network Requirements
- Internet connectivity for downloading packages
- SSH access to the control machine
- AWS API access (443/TCP to AWS endpoints)

## Project Structure

```
VPC_Automation/
├── README.md
├── site.yml                 # Main playbook
├── inventory/
│   ├── hosts               # Inventory file
│   └── group_vars/
│       ├── all.yml         # Global variables
│       └── aws.yml         # AWS-specific variables
├── roles/
│   ├── vpc/                # VPC and networking
│   ├── security/           # Security Groups and NACLs
│   ├── bastion/            # Bastion host setup
│   └── common/             # Common tasks
├── playbooks/
│   ├── deploy.yml          # Deploy infrastructure
│   ├── destroy.yml         # Cleanup infrastructure
│   └── validate.yml        # Validate deployment
└── scripts/
    ├── setup.sh            # Initial setup script
    └── deploy.sh           # Deployment script
```

## Quick Start

### 1. Initial Setup on Ansible Control Machine
```bash
# Clone repository
git clone <repository-url>
cd VPC_Automation

# Run automated setup (installs all dependencies)
./scripts/setup.sh
```

### 2. Configure Your Environment
```bash
# Edit global configuration
nano inventory/group_vars/all.yml
```

**Critical settings to modify:**
```yaml
# Change these values
aws_region: "us-east-1"          # Your preferred AWS region
env_name: "production"           # Environment name
vpc_cidr: "10.0.0.0/16"         # VPC CIDR block

# IMPORTANT: Update with your office IP range for security
ssh_allowed_ips:
  - "203.0.113.0/24"  # Replace with your actual IP range

# Update notification email
notification_email: "your-aws-team@company.com"
```

### 3. Deploy Infrastructure
```bash
# Full deployment with confirmation prompts
./scripts/deploy.sh

# Automated deployment (no prompts)
./scripts/deploy.sh -y

# Test run (see what would be created)
./scripts/deploy.sh -d
```

### 4. Validate Deployment
```bash
# Run validation checks
ansible-playbook -i inventory/hosts playbooks/validate.yml

# Connect to bastion host
./connect-bastion.sh
```

## Configuration

### Variable Files
All configuration is managed through YAML files in `inventory/group_vars/`:

#### `all.yml` - Global Settings
```yaml
# Environment configuration
env_name: "production"                       # Environment name
project_name: "vpc-automation"              # Project identifier
aws_region: "us-east-1"                     # AWS region

# VPC configuration  
vpc_cidr: "10.0.0.0/16"                    # VPC CIDR block
enable_nat_gateway: true                     # Enable NAT Gateway
enable_flow_logs: true                       # Enable VPC Flow Logs

# Security configuration
ssh_allowed_ips:                            # Allowed SSH source IPs
  - "0.0.0.0/0"  # CHANGE THIS FOR SECURITY

# Bastion configuration
bastion_instance_type: "t3.micro"          # Instance size
bastion_ami_id: "ami-0c02fb55956c7d316"    # Amazon Linux 2 AMI

# Cost management
cost_center: "infrastructure"               # Billing tag
notification_email: "aws-team@company.com" # Alert email
```

#### `aws.yml` - AWS-Specific Settings
- Resource naming conventions
- Security group definitions
- Network ACL rules
- VPC endpoint configurations

## Usage

### Deployment Options

#### Full Stack Deployment
```bash
# Complete infrastructure (recommended)
./scripts/deploy.sh

# Or manually
ansible-playbook -i inventory/hosts site.yml
```

#### Component-Specific Deployment
```bash
# VPC and networking only
./scripts/deploy.sh -m vpc-only

# Security groups and NACLs only  
./scripts/deploy.sh -m security-only

# Bastion host only
./scripts/deploy.sh -m bastion-only

# Using tags for granular control
ansible-playbook -i inventory/hosts site.yml --tags "vpc,networking"
```

#### Multi-Environment Deployment
```bash
# Deploy to staging environment
ansible-playbook -i inventory/hosts site.yml -e env_name=staging -e vpc_cidr=10.1.0.0/16

# Deploy to different region
ansible-playbook -i inventory/hosts site.yml -e aws_region=us-west-2
```

#### Validation and Testing
```bash
# Validate deployment
ansible-playbook -i inventory/hosts playbooks/validate.yml

# Test run (dry run)
./scripts/deploy.sh -d

# Verbose output for debugging
ansible-playbook -i inventory/hosts site.yml -v
```

#### Infrastructure Management
```bash
# Update existing infrastructure
ansible-playbook -i inventory/hosts site.yml --diff

# Destroy infrastructure (⚠️ DESTRUCTIVE)
ansible-playbook -i inventory/hosts playbooks/destroy.yml

# Force destroy without confirmation
ansible-playbook -i inventory/hosts playbooks/destroy.yml -e destroy_mode=force
```

## Security Features

### Network Security
- **Multi-layered Security**: Security Groups + Network ACLs
- **Network Segmentation**: Public, Private, and Database subnets
- **Least Privilege Access**: Minimal required permissions
- **Controlled Internet Access**: NAT Gateway for private subnets only

### Security Groups Created
| Security Group | Purpose | Inbound Rules |
|---------------|---------|---------------|
| **Bastion SG** | SSH access | SSH (22) from allowed IPs |
| **Web SG** | Web servers | HTTP/HTTPS from ALB, SSH from Bastion |
| **App SG** | Application servers | App ports from Web tier, SSH from Bastion |
| **DB SG** | Database servers | DB ports from App tier, SSH from Bastion |
| **ALB SG** | Load balancer | HTTP (80), HTTPS (443) from Internet |

### Bastion Host Hardening
- **Fail2Ban**: Intrusion detection and prevention
- **SSH Hardening**: 
  - Root login disabled
  - Password authentication disabled
  - Key-based authentication only
  - Connection limits and timeouts
- **System Monitoring**: CloudWatch agent and alarms
- **Session Manager**: AWS Systems Manager support
- **Automatic Updates**: Security patches applied

### Network ACLs
- **Public NACL**: HTTP/HTTPS, SSH, and ephemeral ports
- **Private NACL**: Internal VPC traffic and controlled outbound
- **Database NACL**: Database traffic from VPC only

### Monitoring & Compliance
- **VPC Flow Logs**: All network traffic logged to CloudWatch
- **CloudWatch Alarms**: CPU, memory, and network monitoring
- **SNS Notifications**: Real-time alerts for security events
- **Tagging Strategy**: Resource identification and cost tracking

## Monitoring and Operations

### Built-in Monitoring
- **VPC Flow Logs**: Network traffic analysis and security monitoring
- **CloudWatch Metrics**: CPU, memory, network, and custom metrics
- **CloudWatch Alarms**: Automated alerting for threshold breaches
- **SNS Integration**: Email and SMS notifications
- **Systems Manager**: Patch management and session access

### Validation Framework
```bash
# Comprehensive infrastructure validation
ansible-playbook -i inventory/hosts playbooks/validate.yml
```

**Validation Checks Include:**
- ✅ VPC existence and availability
- ✅ Internet Gateway attachment
- ✅ NAT Gateway functionality
- ✅ Subnet configuration and availability
- ✅ Security group rules validation
- ✅ Bastion host accessibility
- ✅ Route table configuration
- ✅ VPC Flow Logs activation
- ✅ SSH connectivity tests

### Cost Management
#### Estimated Monthly Costs (us-east-1)
| Resource | Cost/Month | Notes |
|----------|------------|-------|
| VPC, Subnets, IGW | Free | AWS Free Tier |
| NAT Gateway | ~$45 | Data processing charges apply |
| Bastion Host (t3.micro) | ~$9 | Can be stopped when not needed |
| Elastic IPs (2) | ~$7 | One for NAT, one for Bastion |
| VPC Flow Logs | ~$3 | Based on moderate traffic |
| **Total** | **~$64/month** | Varies by usage |

#### Cost Optimization Tips
- **Stop bastion when unused**: Use start/stop automation
- **Right-size instances**: Monitor and adjust instance types
- **Use Spot instances**: For non-critical workloads
- **VPC Endpoints**: Reduce NAT Gateway data charges
- **Reserved Instances**: For long-term predictable workloads

### Backup and Disaster Recovery
- **Infrastructure as Code**: Complete environment recreation
- **Multi-AZ Deployment**: Built-in high availability
- **Automated Snapshots**: EBS volume backup (when configured)
- **Cross-Region Replication**: Deploy to multiple regions
- **Version Control**: All configurations in Git

## Advanced Usage

### Bastion Host Access Methods

#### Method 1: Generated Connection Script
```bash
# Use auto-generated script
./connect-bastion.sh
```

#### Method 2: Direct SSH
```bash
# Direct SSH connection
ssh -i vpc-automation-production-keypair.pem ec2-user@<bastion-public-ip>
```

#### Method 3: SSH Config
```bash
# Add to ~/.ssh/config
cat ssh-config >> ~/.ssh/config

# Connect using alias
ssh vpc-automation-production-bastion
```

#### Method 4: SSH Tunneling for Private Resources
```bash
# Create tunnel to private instance
ssh -i keypair.pem -L 8080:private-instance-ip:80 ec2-user@bastion-ip

# Access private resource via tunnel
curl http://localhost:8080
```

### Multi-Region Deployment

#### Deploy to Multiple Regions
```bash
# Create region-specific variables
cp inventory/group_vars/all.yml inventory/group_vars/us-west-2.yml
cp inventory/group_vars/all.yml inventory/group_vars/eu-west-1.yml

# Edit region-specific settings
nano inventory/group_vars/us-west-2.yml
# Update: aws_region, AMI IDs, etc.

# Deploy to specific region
ansible-playbook -i inventory/hosts site.yml -e "@inventory/group_vars/us-west-2.yml"
```

### Environment Management

#### Development Environment
```bash
# Create dev-specific variables
cp inventory/group_vars/all.yml inventory/group_vars/dev.yml

# Modify for development (smaller instances, different CIDR)
nano inventory/group_vars/dev.yml
# Set: env_name=dev, vpc_cidr=10.10.0.0/16, bastion_instance_type=t3.nano

# Deploy development environment
ansible-playbook -i inventory/hosts site.yml -e "@inventory/group_vars/dev.yml"
```

### Troubleshooting Guide

#### Common Issues and Solutions

**1. AWS Credentials Error**
```bash
# Check current credentials
aws sts get-caller-identity

# Reconfigure if needed
aws configure

# For EC2 instances, attach IAM role
```

**2. Ansible Module Not Found**
```bash
# Reinstall collections
ansible-galaxy collection install amazon.aws --force
ansible-galaxy collection install community.aws --force
```

**3. SSH Connection Refused**
```bash
# Check security group allows your IP
# Verify ssh_allowed_ips in all.yml
# Check key file permissions
chmod 600 *.pem
```

**4. Subnet CIDR Conflicts**
```bash
# Check existing VPCs in region
aws ec2 describe-vpcs --region us-east-1

# Modify vpc_cidr in all.yml to avoid conflicts
```

**5. Resource Limits Exceeded**
```bash
# Check AWS service limits
aws service-quotas list-service-quotas --service-code ec2

# Request limit increases if needed
```

#### Debug Mode
```bash
# Enable verbose output
ansible-playbook -i inventory/hosts site.yml -vvv

# Check Ansible logs
tail -f ansible.log

# Syntax check
ansible-playbook --syntax-check site.yml
```

## Integration Examples

### CI/CD Pipeline Integration

#### GitHub Actions Example
```yaml
name: Deploy VPC Infrastructure
on:
  push:
    branches: [main]
    paths: ['inventory/**', 'roles/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      - name: Deploy infrastructure
        run: |
          pip install ansible boto3
          ./scripts/deploy.sh -y
```

### Terraform Integration
```bash
# Use Terraform for some resources, Ansible for configuration
terraform apply                    # Create base infrastructure
ansible-playbook configure.yml     # Configure and secure resources
```

### Monitoring Integration
```bash
# Deploy with monitoring stack
ansible-playbook -i inventory/hosts site.yml -e enable_monitoring=true

# Integration with external monitoring
# - Datadog agents
# - New Relic infrastructure
# - Prometheus exporters
```

## Contributing

### Development Workflow
1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/new-component`
3. **Make changes and test**: `./scripts/deploy.sh -d`
4. **Commit changes**: `git commit -m "Add new security component"`
5. **Push to branch**: `git push origin feature/new-component`
6. **Create Pull Request** with detailed description

### Coding Standards
- Use descriptive variable names
- Add comments for complex logic
- Follow Ansible best practices
- Test in multiple regions
- Update documentation

### Testing Checklist
- [ ] Syntax validation: `ansible-playbook --syntax-check site.yml`
- [ ] Dry run: `./scripts/deploy.sh -d`
- [ ] Deploy to test environment
- [ ] Run validation: `ansible-playbook -i inventory/hosts playbooks/validate.yml`
- [ ] Test bastion connectivity
- [ ] Verify security group rules
- [ ] Test destruction: `ansible-playbook -i inventory/hosts playbooks/destroy.yml`

## Team Usage Guidelines

### For AWS Management Team

#### Initial Team Setup
1. **Repository Access**: Ensure all team members have access to the Git repository
2. **AWS Permissions**: Provide team members with appropriate IAM permissions
3. **Training**: Conduct training session on the automation tools and processes
4. **Documentation**: Share access to this README and SETUP_GUIDE.md

#### Daily Operations
```bash
# Check infrastructure status
ansible-playbook -i inventory/hosts playbooks/validate.yml

# Deploy updates
git pull origin main
./scripts/deploy.sh --diff

# Connect to bastion for troubleshooting
./connect-bastion.sh
```

#### Emergency Procedures
```bash
# Quick infrastructure recreation
./scripts/deploy.sh -y

# Emergency access to private instances
ssh -i keypair.pem -J ec2-user@bastion-ip ec2-user@private-ip

# Infrastructure rollback (if needed)
git checkout <previous-commit>
./scripts/deploy.sh -y
```

### Best Practices for Teams

#### Version Control
- **Always use Git**: Never deploy without version control
- **Branch Strategy**: Use feature branches for major changes
- **Commit Messages**: Use descriptive commit messages
- **Review Process**: Implement pull request reviews for production

#### Security Guidelines
- **Rotate SSH Keys**: Regularly update EC2 key pairs
- **IP Restrictions**: Keep ssh_allowed_ips updated with current office IPs
- **Monitoring**: Review CloudWatch alarms and VPC Flow Logs regularly
- **Access Control**: Use least privilege principle for team members

#### Change Management
1. **Test First**: Always test changes in development environment
2. **Document Changes**: Update README for any configuration changes
3. **Communicate**: Notify team of infrastructure changes
4. **Backup**: Ensure critical data is backed up before major changes

## Performance Optimization

### Resource Right-Sizing
```bash
# Monitor bastion host usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-1234567890abcdef0 \
  --start-time 2023-01-01T00:00:00Z \
  --end-time 2023-01-07T23:59:59Z \
  --period 3600 \
  --statistics Average
```

### Network Performance
- **Placement Groups**: For high-performance computing workloads
- **Enhanced Networking**: Enable for supported instance types
- **VPC Endpoints**: Reduce NAT Gateway usage for AWS services

### Cost Optimization
- **Instance Scheduling**: Stop non-production instances after hours
- **Reserved Instances**: For predictable workloads
- **Spot Instances**: For fault-tolerant workloads
- **Regular Reviews**: Monthly cost analysis and optimization

## Compliance and Governance

### Compliance Features
- **Tagging Strategy**: Consistent resource tagging for compliance
- **Audit Trails**: VPC Flow Logs and CloudTrail integration
- **Access Control**: IAM roles and security group restrictions
- **Data Protection**: Encryption in transit and at rest

### Governance Framework
- **Change Control**: All changes through version control
- **Approval Process**: Peer review for production changes
- **Documentation**: Maintain up-to-date infrastructure documentation
- **Regular Audits**: Quarterly security and compliance reviews

## Support and Resources

### Internal Support
- **Primary Contact**: AWS Management Team Lead
- **Escalation**: Cloud Architecture Team
- **Emergency**: 24/7 On-call DevOps Team

### External Resources
- **AWS Documentation**: [VPC User Guide](https://docs.aws.amazon.com/vpc/latest/userguide/)
- **Ansible Documentation**: [Ansible AWS Guide](https://docs.ansible.com/ansible/latest/collections/amazon/aws/)
- **Best Practices**: [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

### Issue Reporting
For issues and questions:
- **Bugs**: Create GitHub issues with detailed reproduction steps
- **Feature Requests**: Use GitHub discussions for new feature requests
- **Security Issues**: Report privately to security team
- **Urgent Issues**: Contact on-call team directly

### Community Resources
- **AWS Forums**: [AWS Developer Forums](https://forums.aws.amazon.com/)
- **Ansible Community**: [Ansible Community Forum](https://forum.ansible.com/)
- **Stack Overflow**: Tag questions with `aws-vpc` and `ansible`

## Changelog

### Version 1.0.0 (Current)
- ✅ Complete VPC automation with all components
- ✅ Multi-AZ deployment support
- ✅ Comprehensive security configuration
- ✅ Bastion host with hardening
- ✅ Monitoring and alerting setup
- ✅ Validation and testing framework
- ✅ Cost optimization features

### Roadmap
- 🔄 **v1.1.0**: VPN Gateway integration
- 🔄 **v1.2.0**: Transit Gateway support
- 🔄 **v1.3.0**: Multi-region peering
- 🔄 **v1.4.0**: Container orchestration integration
- 🔄 **v2.0.0**: Terraform hybrid approach

## License

MIT License - see LICENSE file for details

---

**Created by**: AWS Management Team  
**Last Updated**: October 2025  
**Version**: 1.0.0

For the complete setup guide, see [SETUP_GUIDE.md](SETUP_GUIDE.md)