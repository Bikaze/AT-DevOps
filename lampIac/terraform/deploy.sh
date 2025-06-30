#!/bin/bash

# Terraform Deployment Script for LAMP Stack
# This script helps automate the deployment process

set -e

echo "=== LAMP Stack Terraform Deployment ==="
echo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    printf "${1}${2}${NC}\n"
}

# Function to check prerequisites
check_prerequisites() {
    print_color $BLUE "Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_color $RED "Error: Terraform is not installed or not in PATH"
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_color $RED "Error: AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check AWS configuration
    if ! aws sts get-caller-identity &> /dev/null; then
        print_color $RED "Error: AWS CLI is not configured properly"
        print_color $YELLOW "Please run: aws configure"
        exit 1
    fi
    
    print_color $GREEN "✓ Prerequisites check passed"
    echo
}

# Function to initialize Terraform
init_terraform() {
    print_color $BLUE "Initializing Terraform..."
    
    if terraform init; then
        print_color $GREEN "✓ Terraform initialized successfully"
    else
        print_color $RED "✗ Terraform initialization failed"
        exit 1
    fi
    echo
}

# Function to create terraform.tfvars if it doesn't exist
setup_variables() {
    if [ ! -f "terraform.tfvars" ]; then
        print_color $YELLOW "terraform.tfvars not found. Creating from example..."
        cp terraform.tfvars.example terraform.tfvars
        print_color $YELLOW "Please edit terraform.tfvars with your specific values before continuing."
        print_color $YELLOW "Important: Update key_name and db_password at minimum!"
        echo
        read -p "Press Enter after you've edited terraform.tfvars..."
        echo
    fi
}

# Function to validate configuration
validate_terraform() {
    print_color $BLUE "Validating Terraform configuration..."
    
    if terraform validate; then
        print_color $GREEN "✓ Terraform configuration is valid"
    else
        print_color $RED "✗ Terraform configuration validation failed"
        exit 1
    fi
    echo
}

# Function to plan deployment
plan_deployment() {
    print_color $BLUE "Creating deployment plan..."
    
    if terraform plan -out=tfplan; then
        print_color $GREEN "✓ Terraform plan created successfully"
        print_color $YELLOW "Review the plan above to ensure it matches your expectations."
        echo
        read -p "Do you want to proceed with deployment? (yes/no): " confirm
        
        if [ "$confirm" != "yes" ]; then
            print_color $YELLOW "Deployment cancelled by user"
            rm -f tfplan
            exit 0
        fi
    else
        print_color $RED "✗ Terraform plan failed"
        exit 1
    fi
    echo
}

# Function to apply deployment
apply_deployment() {
    print_color $BLUE "Applying Terraform configuration..."
    print_color $YELLOW "This will take approximately 10-15 minutes..."
    echo
    
    if terraform apply tfplan; then
        print_color $GREEN "✓ Infrastructure deployed successfully!"
        rm -f tfplan
    else
        print_color $RED "✗ Terraform apply failed"
        rm -f tfplan
        exit 1
    fi
    echo
}

# Function to troubleshoot deployment
troubleshoot_deployment() {
    print_color $BLUE "Running troubleshooting checks..."
    
    # Check RDS status
    print_color $YELLOW "Checking RDS database status..."
    db_identifier=$(terraform output -raw db_identifier 2>/dev/null || echo "")
    if [ -n "$db_identifier" ]; then
        aws rds describe-db-instances --db-instance-identifier "$db_identifier" \
            --query 'DBInstances[0].DBInstanceStatus' --output text || echo "Could not check RDS status"
    else
        print_color $RED "Could not determine RDS identifier"
    fi
    
    # Check ASG status
    print_color $YELLOW "Checking Auto Scaling Group status..."
    asg_name=$(terraform output -raw asg_name 2>/dev/null || echo "")
    if [ -n "$asg_name" ]; then
        aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name "$asg_name" \
            --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' --output table || echo "Could not check ASG status"
    else
        print_color $RED "Could not determine ASG name"
    fi
    
    # Check Target Group health
    print_color $YELLOW "Checking Target Group health..."
    target_group_arn=$(terraform output -raw target_group_arn 2>/dev/null || echo "")
    if [ -n "$target_group_arn" ]; then
        aws elbv2 describe-target-health --target-group-arn "$target_group_arn" \
            --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Description]' --output table || echo "Could not check target health"
    else
        print_color $RED "Could not determine Target Group ARN"
    fi
    
    # Show connection instructions
    print_color $YELLOW "To SSH into an EC2 instance:"
    instance_ids=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name "$asg_name" \
        --query 'AutoScalingGroups[0].Instances[*].InstanceId' --output text 2>/dev/null || echo "")
    
    if [ -n "$instance_ids" ]; then
        for id in $instance_ids; do
            ip=$(aws ec2 describe-instances --instance-ids $id --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
            key_name=$(terraform output -raw key_name 2>/dev/null || echo "your-key")
            print_color $GREEN "Instance $id IP: $ip"
            echo "ssh -i ~/.ssh/$key_name.pem ubuntu@$ip"
        done
    else
        print_color $RED "No instances found in ASG"
    fi
    
    print_color $YELLOW "To check instance logs and troubleshoot:"
    print_color $GREEN "1. SSH into the instance using the instructions above"
    print_color $GREEN "2. Run: sudo cat /var/log/lamp-setup.log"
    print_color $GREEN "3. Run: sudo docker ps"
    print_color $GREEN "4. Run: sudo docker logs lamp-app"
    echo
}

# Function to show outputs
show_outputs() {
    print_color $BLUE "Deployment outputs:"
    terraform output
    echo
    
    # Get the ALB DNS name for easy access
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    if [ ! -z "$ALB_DNS" ]; then
        print_color $GREEN "Application URLs:"
        echo "  Main application: http://$ALB_DNS"
        echo "  Health check: http://$ALB_DNS/health.php"
        echo
        print_color $YELLOW "Note: It may take 5-10 minutes for instances to be fully healthy."
    fi
}

# Function to test deployment
test_deployment() {
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    
    if [ ! -z "$ALB_DNS" ]; then
        print_color $BLUE "Testing application accessibility..."
        
        # Run troubleshooting checks first
        troubleshoot_deployment
        
        # Wait a bit for the ALB to be ready
        sleep 30
        
        # Test basic connectivity
        if curl -f --max-time 30 "http://$ALB_DNS" > /dev/null 2>&1; then
            print_color $GREEN "✓ Application is accessible"
        else
            print_color $RED "✗ Application is not yet accessible"
            print_color $YELLOW "This might be normal if the instances are still bootstrapping."
            print_color $YELLOW "Check the troubleshooting information above for more details."
        else
            print_color $YELLOW "⚠ Application not yet accessible (may still be starting up)"
        fi
        
        # Test health endpoint
        if curl -f --max-time 30 "http://$ALB_DNS/health.php" > /dev/null 2>&1; then
            print_color $GREEN "✓ Health endpoint is responding"
        else
            print_color $YELLOW "⚠ Health endpoint not yet responding (may still be starting up)"
        fi
    fi
    echo
}

# Function for cleanup
cleanup() {
    print_color $YELLOW "Do you want to destroy the infrastructure? (type 'destroy' to confirm): "
    read confirm
    
    if [ "$confirm" = "destroy" ]; then
        print_color $RED "Destroying infrastructure..."
        terraform destroy
        print_color $GREEN "✓ Infrastructure destroyed"
    else
        print_color $YELLOW "Cleanup cancelled"
    fi
}

# Main execution
case "${1:-deploy}" in
    "deploy")
        check_prerequisites
        init_terraform
        setup_variables
        validate_terraform
        plan_deployment
        apply_deployment
        show_outputs
        test_deployment
        
        print_color $GREEN "=== Deployment Complete! ==="
        print_color $BLUE "Use the following commands to monitor your infrastructure:"
        echo "  terraform output                    # Show all outputs"
        echo "  ./deploy.sh status                  # Check infrastructure status"
        echo "  ./deploy.sh destroy                 # Destroy infrastructure"
        ;;
        
    "status")
        print_color $BLUE "Infrastructure Status:"
        terraform output
        echo
        
        # Check ASG status
        ASG_NAME=$(terraform output -raw auto_scaling_group_name 2>/dev/null || echo "")
        if [ ! -z "$ASG_NAME" ]; then
            print_color $BLUE "Auto Scaling Group Status:"
            aws autoscaling describe-auto-scaling-groups \
                --auto-scaling-group-names "$ASG_NAME" \
                --query 'AutoScalingGroups[0].Instances[*].[InstanceId,LifecycleState,HealthStatus]' \
                --output table \
                --region eu-west-1 2>/dev/null || echo "Error retrieving ASG status"
        fi
        ;;
        
    "destroy")
        cleanup
        ;;
        
    "plan")
        check_prerequisites
        validate_terraform
        terraform plan
        ;;
        
    "init")
        init_terraform
        ;;
        
    *)
        print_color $BLUE "Usage: $0 [command]"
        echo "Commands:"
        echo "  deploy   - Full deployment (default)"
        echo "  status   - Show infrastructure status"
        echo "  destroy  - Destroy infrastructure"
        echo "  plan     - Show deployment plan"
        echo "  init     - Initialize Terraform"
        ;;
esac
