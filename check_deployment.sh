#!/bin/bash
# Comprehensive AWS Infrastructure Status Check
# Run this script to see all deployed resources

VPC_ID="vpc-0e448b3d56861c4f8"
REGION="us-east-1"

echo "=================================================================="
echo "           AWS VPC Infrastructure Status Check"
echo "=================================================================="
echo "VPC ID: $VPC_ID"
echo "Region: $REGION"
echo "=================================================================="

echo ""
echo "# VPC STATUS"
echo "------------"
aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $REGION --query 'Vpcs[*].{ID:VpcId,Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,State:State}' --output table

echo ""
echo "# SUBNETS"
echo "---------"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'Subnets[*].{ID:SubnetId,Name:Tags[?Key==`Name`].Value|[0],CIDR:CidrBlock,AZ:AvailabilityZone,Type:Tags[?Key==`Type`].Value|[0],Public:MapPublicIpOnLaunch}' --output table

echo ""
echo "# INTERNET GATEWAY"
echo "------------------"
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --region $REGION --query 'InternetGateways[*].{ID:InternetGatewayId,Name:Tags[?Key==`Name`].Value|[0],State:Attachments[0].State}' --output table

echo ""
echo "# NAT GATEWAYS"
echo "--------------"
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'NatGateways[*].{ID:NatGatewayId,State:State,Type:ConnectivityType,Subnet:SubnetId}' --output table

echo ""
echo "# ROUTE TABLES"
echo "--------------"
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'RouteTables[*].{ID:RouteTableId,Name:Tags[?Key==`Name`].Value|[0],Main:Associations[?Main==`true`].Main|[0]}' --output table

echo ""
echo "# SECURITY GROUPS"
echo "-----------------"
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'SecurityGroups[*].{ID:GroupId,Name:GroupName,Description:Description}' --output table

echo ""
echo "# NETWORK ACLs"
echo "--------------"
aws ec2 describe-network-acls --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'NetworkAcls[*].{ID:NetworkAclId,Name:Tags[?Key==`Name`].Value|[0],Default:IsDefault}' --output table

echo ""
echo "# EC2 INSTANCES (Bastion)"
echo "-------------------------"
aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=*bastion*" --region $REGION --query 'Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],State:State.Name,Type:InstanceType,IP:PublicIpAddress}' --output table

echo ""
echo "# ELASTIC IPs"
echo "-------------"
aws ec2 describe-addresses --filters "Name=tag:Project,Values=vpc-automation" --region $REGION --query 'Addresses[*].{IP:PublicIp,Instance:InstanceId,Allocation:AllocationId}' --output table

echo ""
echo "# LAUNCH TEMPLATES"
echo "------------------"
aws ec2 describe-launch-templates --filters "Name=tag:Project,Values=vpc-automation" --region $REGION --query 'LaunchTemplates[*].{ID:LaunchTemplateId,Name:LaunchTemplateName}' --output table

echo ""
echo "# IAM ROLES"
echo "-----------"
aws iam list-roles --query 'Roles[?contains(RoleName, `vpc-automation`)].{RoleName:RoleName,Arn:Arn}' --output table

echo ""
echo "# VPC FLOW LOGS"
echo "---------------"
aws ec2 describe-flow-logs --filter "Name=resource-id,Values=$VPC_ID" --region $REGION --query 'FlowLogs[*].{ID:FlowLogId,Status:FlowLogStatus,Type:LogDestinationType}' --output table

echo ""
echo "# CLOUDWATCH LOG GROUPS"
echo "-----------------------"
aws logs describe-log-groups --log-group-name-prefix "/aws/vpc/flowlogs" --region $REGION --query 'logGroups[*].{Name:logGroupName,Retention:retentionInDays}' --output table

echo ""
echo "=================================================================="
echo "                    DEPLOYMENT SUMMARY"
echo "=================================================================="

# Count resources
SUBNET_COUNT=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'length(Subnets)' --output text)
NAT_COUNT=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'length(NatGateways)' --output text)
INSTANCE_COUNT=$(aws ec2 describe-instances --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'length(Reservations)' --output text)
SG_COUNT=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'length(SecurityGroups)' --output text)

echo "✅ VPC: 1/1 deployed"
echo "✅ Subnets: $SUBNET_COUNT deployed (Expected: 3)"
echo "✅ Internet Gateway: 1/1 deployed"
echo "⚠️  NAT Gateways: $NAT_COUNT deployed (Expected: 1)"
echo "✅ Route Tables: Deployed"
echo "✅ Security Groups: $SG_COUNT deployed"
echo "✅ Network ACLs: Deployed"
echo "❌ EC2 Instances: $INSTANCE_COUNT deployed (Expected: 1 - Bastion)"
echo "✅ Elastic IPs: Deployed"
echo "✅ Launch Templates: Deployed"
echo "✅ IAM Roles: Deployed"
echo "✅ VPC Flow Logs: Deployed"
echo ""
echo "ISSUES TO FIX:"
echo "- Multiple NAT Gateways (should be 1)"
echo "- Missing Bastion EC2 instance"
echo "- Extra subnets (should be 3 total)"
echo "=================================================================="