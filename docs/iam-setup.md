# IAM Configuration for GitHub Actions

This document describes the IAM configuration required for GitHub Actions to deploy the VPC infrastructure.

## Required Permissions

The GitHub Actions workflow requires an IAM user with the following permissions:

- EC2 and VPC full access for infrastructure deployment
- IAM permissions for role creation and management
- CloudWatch and CloudWatch Logs for monitoring
- SNS for notifications

## Policy Document

The complete IAM policy is available in `iam/vpc-automation-policy.json`. This policy follows the principle of least privilege while providing the necessary permissions for the automation to function.

## Setting up GitHub Secrets

1. Create an IAM user with the policy
2. Generate access keys for the user
3. Add the following secrets to your GitHub repository:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

## Security Considerations

- Regularly rotate the access keys
- Monitor the IAM user's activity through CloudTrail
- Review and update permissions as needed
- Consider using OIDC federation for more secure authentication

## Permission Details

### EC2 and VPC
- Full access to EC2 and VPC resources
- Ability to create, modify, and delete VPCs, subnets, route tables, etc.

### IAM
- Limited to creating and managing roles prefixed with `vpc-automation-`
- PassRole permission for EC2 instance profiles

### CloudWatch
- Metrics and alarms management
- Log group creation and management

### SNS
- Topic creation and management for notifications
- Limited to topics prefixed with `vpc-automation-`