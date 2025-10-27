# SSH Key Management Best Practices for AWS Management Team

## Overview
This document outlines best practices for SSH key management in the AWS VPC automation project, focusing on team access and security.

## Current Implementation

### SSH Key Generation
- **Local Keys**: Generated during setup (`~/.ssh/id_rsa`) for Ansible control
- **AWS Key Pairs**: Created in EC2 for bastion host access
- **Private Key Storage**: Saved locally as `.pem` files in project directory

### Access Methods
1. **SSH with Key Pairs** (Traditional)
   - Requires private key file management
   - Key distribution to team members
   - Manual key rotation

2. **AWS Session Manager** (Recommended for Teams)
   - No SSH keys needed
   - IAM-based access control
   - Auditable session logs
   - Secure access without key management

## Best Practices

### 1. Use AWS Session Manager for Team Access
```bash
# Connect via Session Manager (recommended)
aws ssm start-session --target i-1234567890abcdef0 --region us-east-1

# Or use the generated script
./connect-bastion-ssm.sh
```

**Advantages:**
- No private keys to manage or distribute
- IAM controls access (principle of least privilege)
- Session logging and auditing
- No key rotation required
- Works through firewalls/proxies

### 2. SSH Key Management (When Required)
- **Never commit private keys** to version control
- Use `.gitignore` to exclude `.pem` files
- Rotate keys regularly (90-180 days)
- Use different keys for different environments
- Store keys securely (password managers, HSMs)

### 3. Team Key Distribution
If SSH keys must be used:
- Use secure channels (encrypted email, secure file sharing)
- Implement key management policies
- Document key ownership and rotation procedures
- Consider using SSH certificates instead of keys

### 4. IAM Permissions for Session Manager
Ensure team members have:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:StartSession",
        "ssm:TerminateSession"
      ],
      "Resource": [
        "arn:aws:ec2:region:account:instance/bastion-instance-id"
      ]
    }
  ]
}
```

## Security Recommendations

### For Individual Access
1. Use Session Manager when possible
2. If SSH required, use personal key pairs
3. Enable MFA on AWS accounts
4. Use AWS SSO for centralized access

### For Team Access
1. **Primary**: Session Manager with IAM roles
2. **Secondary**: Shared SSH keys with strict access controls
3. **Avoid**: Distributing private keys widely

### Key Rotation Strategy
- Rotate SSH keys every 90 days
- Use automation for key rotation
- Notify team members of upcoming rotations
- Maintain backup access methods during transitions

## Implementation Checklist

- [ ] Enable Session Manager on bastion host
- [ ] Configure IAM permissions for team members
- [ ] Test Session Manager connectivity
- [ ] Document access procedures
- [ ] Set up monitoring and alerting for unauthorized access attempts
- [ ] Implement key rotation procedures
- [ ] Add .pem files to .gitignore

## Emergency Access
- Maintain backup SSH access for emergency situations
- Document emergency access procedures
- Regularly test emergency access methods
- Limit emergency access to authorized personnel only

## Monitoring and Auditing
- Enable CloudTrail for Session Manager activity
- Monitor SSH access logs on bastion host
- Set up alerts for suspicious access patterns
- Regular security audits of access methods