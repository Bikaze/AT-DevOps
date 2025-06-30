#!/bin/bash

# Exit on error for critical failures, but handle expected errors gracefully
set -e

# Configuration
export REGION="eu-west-1" # Change to your region
export ASG_NAME="php-asg"
export ALB_NAME="php-alb"
export TARGET_GROUP_NAME="php-targets"
export LAUNCH_TEMPLATE_NAME="php-launch-template"

# Security Group Names (will be deleted if no resources are using them)
export ALB_SG_NAME="PHP-ALB-SG"
export APP_SG_NAME="PHP-App-SG"
export RDS_SG_NAME="PHP-RDS-SG"

echo "=== Starting AWS LAMP Infrastructure Cleanup ==="
echo "WARNING: This will delete ALB, ASG, Launch Template, Target Groups, and unused Security Groups"
echo "Database resources will be preserved"
echo ""

read -p "Are you sure you want to proceed? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo "Starting cleanup process..."
echo "First, let's discover what resources exist..."

# Function to safely check if a resource exists and return status
resource_exists() {
    local resource_type=$1
    local resource_identifier=$2
    local aws_command=$3
    
    echo -n "Checking $resource_type ($resource_identifier)... "
    
    local result=$(eval "$aws_command" 2>/dev/null)
    if [ ! -z "$result" ] && [ "$result" != "None" ] && [ "$result" != "null" ]; then
        echo "EXISTS"
        return 0
    else
        echo "NOT FOUND"
        return 1
    fi
}

# Function to safely get AWS CLI output
safe_aws_output() {
    local aws_command=$1
    local default_value=${2:-""}
    
    eval "$aws_command" 2>/dev/null || echo "$default_value"
}

echo ""
echo "=== RESOURCE DISCOVERY PHASE ==="

# Discover Auto Scaling Groups
echo ""
echo "1. Discovering Auto Scaling Groups..."
ASG_EXISTS=false
ASG_INSTANCES=""
if resource_exists "Auto Scaling Group" "$ASG_NAME" "aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --region $REGION --query 'AutoScalingGroups[0].AutoScalingGroupName' --output text"; then
    ASG_EXISTS=true
    ASG_DETAILS=$(safe_aws_output "aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names $ASG_NAME \
        --region $REGION \
        --query 'AutoScalingGroups[0].[AutoScalingGroupName,MinSize,MaxSize,DesiredCapacity]' \
        --output text")
    echo "  ASG Details: $ASG_DETAILS"
    
    # Get instances in ASG - handle case where there are no instances
    ASG_INSTANCES=$(safe_aws_output "aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names $ASG_NAME \
        --region $REGION \
        --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
        --output text")
    
    if [ ! -z "$ASG_INSTANCES" ] && [ "$ASG_INSTANCES" != "None" ]; then
        echo "  Instances in ASG: $ASG_INSTANCES"
    else
        echo "  No instances currently in ASG"
        ASG_INSTANCES=""
    fi
fi

# Discover Application Load Balancers
echo ""
echo "2. Discovering Application Load Balancers..."
ALB_EXISTS=false
ALB_ARN=""
LISTENERS=""
if resource_exists "Application Load Balancer" "$ALB_NAME" "aws elbv2 describe-load-balancers --names $ALB_NAME --region $REGION --query 'LoadBalancers[0].LoadBalancerArn' --output text"; then
    ALB_EXISTS=true
    ALB_ARN=$(safe_aws_output "aws elbv2 describe-load-balancers \
        --names $ALB_NAME \
        --region $REGION \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text")
    ALB_DNS=$(safe_aws_output "aws elbv2 describe-load-balancers \
        --names $ALB_NAME \
        --region $REGION \
        --query 'LoadBalancers[0].DNSName' \
        --output text")
    echo "  ALB ARN: $ALB_ARN"
    echo "  ALB DNS: $ALB_DNS"
    
    # Get listeners
    LISTENERS=$(safe_aws_output "aws elbv2 describe-listeners \
        --load-balancer-arn $ALB_ARN \
        --region $REGION \
        --query 'Listeners[*].ListenerArn' \
        --output text")
    if [ ! -z "$LISTENERS" ] && [ "$LISTENERS" != "None" ]; then
        echo "  Listeners: $LISTENERS"
    else
        echo "  No listeners found"
        LISTENERS=""
    fi
fi

# Discover Target Groups
echo ""
echo "3. Discovering Target Groups..."
TG_EXISTS=false
TG_ARN=""
TARGETS=""
if resource_exists "Target Group" "$TARGET_GROUP_NAME" "aws elbv2 describe-target-groups --names $TARGET_GROUP_NAME --region $REGION --query 'TargetGroups[0].TargetGroupArn' --output text"; then
    TG_EXISTS=true
    TG_ARN=$(safe_aws_output "aws elbv2 describe-target-groups \
        --names $TARGET_GROUP_NAME \
        --region $REGION \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text")
    echo "  Target Group ARN: $TG_ARN"
    
    # Get registered targets
    TARGETS=$(safe_aws_output "aws elbv2 describe-target-health \
        --target-group-arn $TG_ARN \
        --region $REGION \
        --query 'TargetHealthDescriptions[*].Target.Id' \
        --output text")
    if [ ! -z "$TARGETS" ] && [ "$TARGETS" != "None" ]; then
        echo "  Registered targets: $TARGETS"
    else
        echo "  No registered targets"
        TARGETS=""
    fi
fi

# Discover Launch Templates
echo ""
echo "4. Discovering Launch Templates..."
LT_EXISTS=false
if resource_exists "Launch Template" "$LAUNCH_TEMPLATE_NAME" "aws ec2 describe-launch-templates --launch-template-names $LAUNCH_TEMPLATE_NAME --region $REGION --query 'LaunchTemplates[0].LaunchTemplateName' --output text"; then
    LT_EXISTS=true
    LT_DETAILS=$(safe_aws_output "aws ec2 describe-launch-templates \
        --launch-template-names $LAUNCH_TEMPLATE_NAME \
        --region $REGION \
        --query 'LaunchTemplates[0].[LaunchTemplateName,LaunchTemplateId,DefaultVersionNumber]' \
        --output text")
    echo "  Launch Template Details: $LT_DETAILS"
fi

# Discover Security Groups
echo ""
echo "5. Discovering Security Groups..."
declare -A SECURITY_GROUPS
SG_NAMES=("$ALB_SG_NAME" "$APP_SG_NAME" "$RDS_SG_NAME")

for sg_name in "${SG_NAMES[@]}"; do
    if resource_exists "Security Group" "$sg_name" "aws ec2 describe-security-groups --group-names $sg_name --region $REGION --query 'SecurityGroups[0].GroupId' --output text"; then
        SG_ID=$(safe_aws_output "aws ec2 describe-security-groups \
            --group-names $sg_name \
            --region $REGION \
            --query 'SecurityGroups[0].GroupId' \
            --output text")
        if [ ! -z "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
            SECURITY_GROUPS[$sg_name]=$SG_ID
            echo "  $sg_name: $SG_ID"
        fi
    fi
done

# Check for scaling policies
echo ""
echo "6. Discovering Scaling Policies..."
SCALING_POLICIES=""
if [ "$ASG_EXISTS" = true ]; then
    SCALING_POLICIES=$(safe_aws_output "aws autoscaling describe-policies \
        --auto-scaling-group-name $ASG_NAME \
        --region $REGION \
        --query 'ScalingPolicies[*].PolicyName' \
        --output text")
    if [ ! -z "$SCALING_POLICIES" ] && [ "$SCALING_POLICIES" != "None" ]; then
        echo "  Found scaling policies: $SCALING_POLICIES"
    else
        echo "  No scaling policies found"
        SCALING_POLICIES=""
    fi
fi

# Check for CloudWatch Alarms
echo ""
echo "7. Discovering CloudWatch Alarms..."
CW_ALARMS=$(safe_aws_output "aws cloudwatch describe-alarms \
    --alarm-name-prefix \"TargetTracking-$ASG_NAME\" \
    --region $REGION \
    --query 'MetricAlarms[*].AlarmName' \
    --output text")
if [ ! -z "$CW_ALARMS" ] && [ "$CW_ALARMS" != "None" ]; then
    echo "  Found CloudWatch alarms: $CW_ALARMS"
else
    echo "  No CloudWatch alarms found"
    CW_ALARMS=""
fi

# Check for orphaned instances
echo ""
echo "8. Discovering Orphaned Instances..."
ORPHANED_INSTANCES=$(safe_aws_output "aws ec2 describe-instances \
    --filters Name=tag:Name,Values=PHP-LAMP-Instance,PHP-ASG-Instance Name=instance-state-name,Values=running,pending,stopping,stopped \
    --region $REGION \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text")
if [ ! -z "$ORPHANED_INSTANCES" ] && [ "$ORPHANED_INSTANCES" != "None" ]; then
    echo "  Found orphaned instances: $ORPHANED_INSTANCES"
else
    echo "  No orphaned instances found"
    ORPHANED_INSTANCES=""
fi

echo ""
echo "=== RESOURCE DISCOVERY COMPLETE ==="
echo ""
echo "Summary of resources found:"
echo "  Auto Scaling Group: $ASG_EXISTS"
echo "  Application Load Balancer: $ALB_EXISTS"
echo "  Target Group: $TG_EXISTS"
echo "  Launch Template: $LT_EXISTS"
echo "  Security Groups: ${#SECURITY_GROUPS[@]} found"
echo "  Scaling Policies: $([ -z "$SCALING_POLICIES" ] && echo "0" || echo "$(echo $SCALING_POLICIES | wc -w)")"
echo "  CloudWatch Alarms: $([ -z "$CW_ALARMS" ] && echo "0" || echo "$(echo $CW_ALARMS | wc -w)")"
echo "  Orphaned Instances: $([ -z "$ORPHANED_INSTANCES" ] && echo "0" || echo "$(echo $ORPHANED_INSTANCES | wc -w)")"

echo ""
read -p "Proceed with deletion of found resources? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "=== DELETION PHASE ==="
echo "Deleting resources in dependency order (least dependent first)..."

# Phase 1: Handle orphaned instances first (they're independent)
if [ ! -z "$ORPHANED_INSTANCES" ]; then
    echo ""
    echo "Phase 1: Handling Orphaned Instances..."
    echo "Found orphaned instances: $ORPHANED_INSTANCES"
    read -p "Do you want to terminate these instances? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Terminating orphaned instances..."
        aws ec2 terminate-instances \
            --instance-ids $ORPHANED_INSTANCES \
            --region $REGION
        echo "✓ Instances marked for termination"
    else
        echo "Skipping instance termination"
    fi
else
    echo "Phase 1: No orphaned instances found"
fi

# Phase 2: Delete Auto Scaling Group (handles its own instances)
if [ "$ASG_EXISTS" = true ]; then
    echo ""
    echo "Phase 2: Deleting Auto Scaling Group..."
    
    # Just delete the ASG directly with force-delete
    # The --force-delete flag will terminate all instances automatically
    echo "Deleting Auto Scaling Group with force-delete (this will terminate all instances)..."
    aws autoscaling delete-auto-scaling-group \
        --auto-scaling-group-name $ASG_NAME \
        --force-delete \
        --region $REGION
    
    echo "✓ Auto Scaling Group deleted successfully (instances will terminate automatically)"
else
    echo "Phase 2: Auto Scaling Group not found, skipping..."
fi

# Phase 3: Delete scaling policies (cleanup any that might remain)
if [ ! -z "$SCALING_POLICIES" ]; then
    echo ""
    echo "Phase 3: Cleaning up any remaining Scaling Policies..."
    for policy in $SCALING_POLICIES; do
        echo "Attempting to delete scaling policy: $policy"
        aws autoscaling delete-policy \
            --policy-name $policy \
            --region $REGION 2>/dev/null || echo "Policy may already be deleted: $policy"
    done
    echo "✓ Scaling policies cleanup completed"
else
    echo "Phase 3: No scaling policies to clean up"
fi

# Phase 4: Clean up CloudWatch Alarms
if [ ! -z "$CW_ALARMS" ]; then
    echo ""
    echo "Phase 4: Cleaning up CloudWatch Alarms..."
    for alarm in $CW_ALARMS; do
        echo "Deleting alarm: $alarm"
        aws cloudwatch delete-alarms \
            --alarm-names $alarm \
            --region $REGION 2>/dev/null || echo "Alarm may already be deleted: $alarm"
    done
    echo "✓ CloudWatch alarms deleted"
else
    echo "Phase 4: No CloudWatch alarms to clean up"
fi

# Phase 5: Delete Application Load Balancer
if [ "$ALB_EXISTS" = true ]; then
    echo ""
    echo "Phase 5: Deleting Application Load Balancer..."
    
    # Delete listeners first
    if [ ! -z "$LISTENERS" ]; then
        echo "Deleting ALB listeners..."
        for listener_arn in $LISTENERS; do
            echo "Deleting listener: $listener_arn"
            aws elbv2 delete-listener \
                --listener-arn $listener_arn \
                --region $REGION 2>/dev/null || echo "Listener may already be deleted"
        done
    fi
    
    # Delete the load balancer
    echo "Deleting Application Load Balancer..."
    aws elbv2 delete-load-balancer \
        --load-balancer-arn $ALB_ARN \
        --region $REGION
    
    echo "Waiting for ALB to be deleted..."
    aws elbv2 wait load-balancer-deleted \
        --load-balancer-arns $ALB_ARN \
        --region $REGION 2>/dev/null || echo "ALB deletion completed"
    
    echo "✓ Application Load Balancer deleted successfully"
else
    echo "Phase 5: Application Load Balancer not found, skipping..."
fi

# Phase 6: Delete Target Groups
if [ "$TG_EXISTS" = true ]; then
    echo ""
    echo "Phase 6: Deleting Target Groups..."
    
    echo "Deleting Target Group..."
    aws elbv2 delete-target-group \
        --target-group-arn $TG_ARN \
        --region $REGION
    
    echo "✓ Target Group deleted successfully"
else
    echo "Phase 6: Target Group not found, skipping..."
fi

# Phase 7: Delete Launch Template
if [ "$LT_EXISTS" = true ]; then
    echo ""
    echo "Phase 7: Deleting Launch Template..."
    
    aws ec2 delete-launch-template \
        --launch-template-name $LAUNCH_TEMPLATE_NAME \
        --region $REGION
    
    echo "✓ Launch Template deleted successfully"
else
    echo "Phase 7: Launch Template not found, skipping..."
fi

# Phase 8: Clean up Security Groups (last, as they may be referenced)
if [ ${#SECURITY_GROUPS[@]} -gt 0 ]; then
    echo ""
    echo "Phase 8: Cleaning up Security Groups..."
    
    # Wait a moment for resources to fully delete
    echo "Waiting 30 seconds for resources to fully delete before cleaning security groups..."
    sleep 30
    
    # Delete in reverse dependency order
    for sg_name in "$ALB_SG_NAME" "$APP_SG_NAME" "$RDS_SG_NAME"; do
        if [ -v SECURITY_GROUPS[$sg_name] ]; then
            SG_ID=${SECURITY_GROUPS[$sg_name]}
            echo "Checking if Security Group can be deleted: $sg_name ($SG_ID)"
            
            # Check if security group is in use by any instances
            INSTANCES_USING_SG=$(safe_aws_output "aws ec2 describe-instances \
                --filters Name=instance.group-id,Values=$SG_ID Name=instance-state-name,Values=running,pending,stopping,stopped \
                --region $REGION \
                --query 'Reservations[*].Instances[*].InstanceId' \
                --output text")
            
            # Check if security group is referenced by other security groups
            REFERENCED_BY=$(safe_aws_output "aws ec2 describe-security-groups \
                --filters Name=ip-permission.group-id,Values=$SG_ID \
                --region $REGION \
                --query 'SecurityGroups[*].GroupId' \
                --output text")
            
            # Check if referenced by load balancers
            ALB_USING_SG=$(safe_aws_output "aws elbv2 describe-load-balancers \
                --region $REGION \
                --query \"LoadBalancers[?contains(SecurityGroups, '$SG_ID')].LoadBalancerArn\" \
                --output text")
            
            if [ -z "$INSTANCES_USING_SG" ] && [ -z "$REFERENCED_BY" ] && [ -z "$ALB_USING_SG" ] && \
               [ "$INSTANCES_USING_SG" != "None" ] && [ "$REFERENCED_BY" != "None" ] && [ "$ALB_USING_SG" != "None" ]; then
                echo "Deleting unused Security Group: $sg_name"
                aws ec2 delete-security-group \
                    --group-id $SG_ID \
                    --region $REGION 2>/dev/null && echo "✓ Security Group deleted: $sg_name" || echo "Failed to delete Security Group: $sg_name (may still be in use)"
            else
                echo "Security Group is still in use, skipping: $sg_name"
                if [ ! -z "$INSTANCES_USING_SG" ] && [ "$INSTANCES_USING_SG" != "None" ]; then
                    echo "  Used by instances: $INSTANCES_USING_SG"
                fi
                if [ ! -z "$REFERENCED_BY" ] && [ "$REFERENCED_BY" != "None" ]; then
                    echo "  Referenced by security groups: $REFERENCED_BY"
                fi
                if [ ! -z "$ALB_USING_SG" ] && [ "$ALB_USING_SG" != "None" ]; then
                    echo "  Used by load balancers: $ALB_USING_SG"
                fi
            fi
        fi
    done
else
    echo "Phase 8: No security groups found to clean up"
fi

echo ""
echo "=== CLEANUP COMPLETE! ==="
echo ""
echo "Resources that were processed:"
echo "✓ Auto Scaling Group: $([ "$ASG_EXISTS" = true ] && echo "DELETED" || echo "NOT FOUND")"
echo "✓ Application Load Balancer: $([ "$ALB_EXISTS" = true ] && echo "DELETED" || echo "NOT FOUND")"
echo "✓ Target Group: $([ "$TG_EXISTS" = true ] && echo "DELETED" || echo "NOT FOUND")"
echo "✓ Launch Template: $([ "$LT_EXISTS" = true ] && echo "DELETED" || echo "NOT FOUND")"
echo "✓ Security Groups: PROCESSED (deleted if unused)"
echo "✓ CloudWatch Alarms: $([ ! -z "$CW_ALARMS" ] && echo "DELETED" || echo "NOT FOUND")"
echo "✓ Orphaned Instances: $([ ! -z "$ORPHANED_INSTANCES" ] && echo "PROCESSED" || echo "NOT FOUND")"
echo ""
echo "Resources preserved:"
echo "✓ RDS Database instances"
echo "✓ DB Subnet Groups"
echo "✓ Security Groups (if still in use by RDS or other resources)"
echo ""
echo "Note: Some resources may take a few minutes to fully delete."
echo "You can verify the cleanup by checking the AWS console."