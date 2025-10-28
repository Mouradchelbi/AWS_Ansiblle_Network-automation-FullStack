#!/bin/bash
# Cleanup duplicate AWS resources from multiple playbook runs

REGION="us-east-1"
VPC_ID="vpc-0e448b3d56861c4f8"

echo "=================================================================="
echo "           AWS VPC Infrastructure Cleanup"
echo "=================================================================="
echo "VPC ID: $VPC_ID"
echo "Region: $REGION"
echo "=================================================================="

# CLEANUP NAT GATEWAYS
echo ""
echo "# CLEANING UP NAT GATEWAYS"
echo "---------------------------"

# Get all NAT Gateway IDs
NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'NatGateways[*].NatGatewayId' --output text)

echo "Found NAT Gateways: $NAT_GATEWAYS"

# Convert to array
IFS=' ' read -r -a NAT_ARRAY <<< "$NAT_GATEWAYS"

if [ ${#NAT_ARRAY[@]} -gt 1 ]; then
    echo ""
    echo "⚠️  Found ${#NAT_ARRAY[@]} NAT Gateways. Keeping the first one: ${NAT_ARRAY[0]}"

    # Keep the first NAT Gateway, delete the rest
    for ((i=1; i<${#NAT_ARRAY[@]}; i++)); do
        echo "🗑️  Deleting NAT Gateway: ${NAT_ARRAY[i]}"
        aws ec2 delete-nat-gateway --nat-gateway-id ${NAT_ARRAY[i]} --region $REGION
        echo "✅ Deleted NAT Gateway: ${NAT_ARRAY[i]}"
    done
else
    echo "✅ Only 1 NAT Gateway found - no cleanup needed"
fi

# CLEANUP DATABASE SUBNETS
echo ""
echo "# CLEANING UP DATABASE SUBNETS"
echo "-------------------------------"

# Get all database subnets
DB_SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Type,Values=DatabaseSubnet" --region $REGION --query 'Subnets[*].{ID:SubnetId,Name:Tags[?Key==`Name`].Value|[0]}' --output text)

echo "Found Database Subnets:"
echo "$DB_SUBNETS"

# Get subnet IDs only (first column)
DB_SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Type,Values=DatabaseSubnet" --region $REGION --query 'Subnets[*].SubnetId' --output text)

# Convert to array
IFS=' ' read -r -a DB_ARRAY <<< "$DB_SUBNET_IDS"

if [ ${#DB_ARRAY[@]} -gt 1 ]; then
    echo ""
    echo "⚠️  Found ${#DB_ARRAY[@]} Database Subnets. Keeping the first one: ${DB_ARRAY[0]}"

    # Keep the first database subnet, delete the rest
    for ((i=1; i<${#DB_ARRAY[@]}; i++)); do
        echo "🗑️  Deleting Database Subnet: ${DB_ARRAY[i]}"
        aws ec2 delete-subnet --subnet-id ${DB_ARRAY[i]} --region $REGION
        echo "✅ Deleted Database Subnet: ${DB_ARRAY[i]}"
    done
else
    echo "✅ Only 1 Database Subnet found - no cleanup needed"
fi

echo ""
echo "# CLEANUP COMPLETE"
echo "=================================================================="