# LAMP Stack Terraform Infrastructure

## Overview

This Terraform configuration deploys a scalable LAMP (Linux, Apache, MySQL, PHP) stack on AWS using modern best practices and Infrastructure as Code principles.

## Architecture

### Components

1. **Auto Scaling Group (ASG)** - Manages EC2 instances running the LAMP application
2. **Application Load Balancer (ALB)** - Distributes traffic across healthy instances
3. **RDS MySQL Database** - Managed database service
4. **Security Groups** - Network security controls
5. **CloudWatch Monitoring** - Alarms and metrics
6. **IAM Roles** - Permissions for EC2 instances

### Infrastructure Diagram

```
Internet
    |
    v
Application Load Balancer (ALB)
    |
    v
Auto Scaling Group (ASG)
    |
    v
EC2 Instances (t2.micro)
    |
    v
RDS MySQL Database
```

## Terraform Concepts

### What is Terraform?

Terraform is an Infrastructure as Code (IaC) tool that allows you to:

- **Define infrastructure** using declarative configuration files
- **Version control** your infrastructure changes
- **Plan changes** before applying them
- **Manage state** of your infrastructure
- **Collaborate** with team members

### Key Terraform Files

- **`main.tf`** - Main configuration file that orchestrates all modules
- **`variables.tf`** - Input variables for configuration
- **`outputs.tf`** - Output values from the infrastructure
- **`terraform.tfvars`** - Variable values (not in version control)
- **`terraform.tfstate`** - State file tracking actual infrastructure

### Terraform Modules

Modules are reusable components that group related resources. This project uses:

- **`modules/security_groups/`** - Network security rules
- **`modules/iam/`** - Identity and access management
- **`modules/rds/`** - Database infrastructure
- **`modules/alb/`** - Load balancer configuration
- **`modules/asg/`** - Auto scaling group and launch template
- **`modules/cloudwatch/`** - Monitoring and alarms

## Directory Structure

```
terraform/
├── main.tf                           # Main configuration
├── variables.tf                      # Input variables
├── outputs.tf                        # Output values
├── terraform.tfvars.example          # Example variables file
├── README.md                         # This file
└── modules/
    ├── security_groups/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── iam/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── rds/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── alb/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── asg/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── user_data.sh
    └── cloudwatch/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Prerequisites

### 1. Install Terraform

Terraform should already be installed on your machine. Verify with:

```bash
terraform version
```

### 2. AWS CLI Configuration

Ensure AWS CLI is configured with appropriate credentials:

```bash
aws configure
```

Required permissions:

- EC2 (instances, security groups, load balancers)
- RDS (database instances, subnet groups)
- IAM (roles, policies, instance profiles)
- CloudWatch (alarms, metrics)
- Auto Scaling (groups, policies)

### 3. Key Pair

Ensure you have an EC2 key pair created in the eu-west-1 region for SSH access.

## Deployment Instructions

### Step 1: Initialize Terraform

Navigate to the terraform directory and initialize:

```bash
cd terraform
terraform init
```

This command:

- Downloads required providers (AWS)
- Initializes the backend
- Prepares modules

### Step 2: Configure Variables

1. Copy the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your specific values:

```bash
nano terraform.tfvars
```

**Important variables to modify:**

- `key_name` - Your EC2 key pair name
- `db_password` - A secure database password
- `ami_id` - Verify this is the latest Ubuntu 22.04 LTS AMI for eu-west-1

### Step 3: Plan the Deployment

Review what Terraform will create:

```bash
terraform plan
```

This shows:

- Resources to be created
- Dependencies between resources
- Any potential issues

### Step 4: Apply the Configuration

Deploy the infrastructure:

```bash
terraform apply
```

- Review the plan one more time
- Type `yes` to confirm
- Wait 10-15 minutes for deployment to complete

### Step 5: Verify Deployment

After successful deployment, Terraform will output:

- ALB DNS name
- Application URL
- Database endpoint
- Security group IDs

Test the application:

```bash
# Replace with your actual ALB DNS name from output
curl http://your-alb-dns-name.eu-west-1.elb.amazonaws.com
curl http://your-alb-dns-name.eu-west-1.elb.amazonaws.com/health.php
```

## Configuration Options

### Scaling Configuration

Modify these variables in `terraform.tfvars`:

```hcl
min_size         = 1    # Minimum instances
max_size         = 5    # Maximum instances
desired_capacity = 2    # Initial number of instances
```

### Instance Configuration

```hcl
instance_type = "t2.micro"    # Instance size (free tier)
```

### Database Configuration

```hcl
db_instance_class = "db.t3.micro"  # Database size (free tier)
allocated_storage = 20             # Storage in GB (free tier)
```

## Monitoring and Scaling

### Auto Scaling Policies

The infrastructure includes:

1. **Target Tracking Scaling** - Maintains 70% CPU utilization
2. **Step Scaling** - Emergency scaling at 85% CPU

### CloudWatch Alarms

- **High CPU** - Triggers emergency scaling
- **ALB Response Time** - Monitors application performance
- **Unhealthy Hosts** - Alerts on failed instances

### Monitoring Commands

```bash
# Check Auto Scaling Group status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names php-lamp-app-asg \
  --region eu-west-1

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region eu-west-1

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum \
  --region eu-west-1
```

## Customization

### Adding Environment Variables

Edit `modules/asg/user_data.sh` to add new environment variables:

```bash
docker run -d \
  --name lamp-app \
  -p 80:80 \
  -e DB_HOST="${db_host}" \
  -e NEW_VAR="value" \
  bikaze/lamp
```

### Modifying Security Groups

Edit `modules/security_groups/main.tf` to add new rules:

```hcl
ingress {
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "HTTPS access"
}
```

### Adding SSL/TLS

To add HTTPS support:

1. Request an ACM certificate
2. Add HTTPS listener to ALB
3. Redirect HTTP to HTTPS

## Troubleshooting

### Common Issues and Solutions

1. **SSH Access Not Working**

   - **Problem**: Unable to SSH into EC2 instances
   - **Solutions**:
     - Verify your key pair exists in the eu-west-1 region and matches `key_name` in terraform.tfvars
     - Ensure security groups allow SSH (port 22) from your IP address
     - Check that instances have public IP addresses assigned
     - Verify network ACLs allow SSH traffic
     - Use the troubleshooting function in deploy.sh to get the correct SSH command

2. **Health Checks Failing**

   - **Problem**: Instances fail ALB health checks
   - **Solutions**:
     - Check the user data script logs: `sudo cat /var/log/lamp-setup.log`
     - Verify Docker is running: `sudo systemctl status docker`
     - Ensure the Docker container is running: `sudo docker ps`
     - Check Docker logs: `sudo docker logs lamp-app`
     - Verify health check endpoint is accessible: `curl http://localhost/health.php`
     - Check security groups allow HTTP (port 80) from the ALB

3. **Database Connection Issues**

   - **Problem**: Application cannot connect to the RDS database
   - **Solutions**:
     - Verify RDS instance is available: `aws rds describe-db-instances --db-instance-identifier <db_identifier>`
     - Check security group rules allow MySQL (port 3306) from the app security group
     - Verify database credentials are correct in the environment variables
     - Test connection from EC2 instance: `nc -zv <rds_endpoint> 3306`

4. **LoadBalancer Not Accessible**
   - **Problem**: Cannot access the application through the ALB
   - **Solutions**:
     - Verify instances are registered with the target group and healthy
     - Check ALB security group allows HTTP/HTTPS from the internet
     - Ensure the ALB listener is correctly configured
     - Check that the target group health check path is valid

### Detailed Debugging

```bash
# Run the troubleshooting function
./deploy.sh troubleshoot

# Get instance IDs from Auto Scaling Group
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name <asg_name> --query 'AutoScalingGroups[0].Instances[*].[InstanceId]' --output text

# Check instance status
aws ec2 describe-instance-status --instance-ids <instance_id>

# SSH into instance (obtain IP from troubleshooting output)
ssh -i ~/.ssh/<key_name>.pem ubuntu@<instance_public_ip>

# Check Docker container status
sudo docker ps
sudo docker logs lamp-app

# View application logs
sudo cat /var/log/lamp-setup.log
sudo journalctl -u docker.service

# Test health check endpoint
curl http://localhost/
curl http://localhost/health.php

# Check database connectivity from instance
nc -zv <db_endpoint> 3306
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=php-lamp-app-instance" \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]' \
  --output table \
  --region eu-west-1
```

## Cleanup

To destroy the infrastructure:

```bash
terraform destroy
```

**Warning:** This will delete all resources. Ensure you have backups if needed.

## Security Considerations

### Production Recommendations

1. **Database Security**

   - Use AWS Secrets Manager for database passwords
   - Enable encryption at rest
   - Restrict security group access

2. **Network Security**

   - Remove SSH access from 0.0.0.0/0
   - Use a bastion host for SSH access
   - Consider using private subnets for instances

3. **Application Security**

   - Implement WAF for the ALB
   - Use HTTPS with valid certificates
   - Enable CloudTrail for audit logging

4. **Access Control**
   - Use least privilege IAM policies
   - Enable MFA for AWS accounts
   - Regular security audits

## Cost Optimization

### Free Tier Resources

This configuration uses AWS Free Tier eligible resources:

- t2.micro EC2 instances (750 hours/month)
- db.t3.micro RDS instance (750 hours/month)
- 20GB EBS storage
- Application Load Balancer (15GB data processing)

### Cost Monitoring

- Set up billing alerts
- Use AWS Cost Explorer
- Consider Reserved Instances for production

## Support

For issues and questions:

1. Check AWS CloudWatch logs
2. Review Terraform state and plan
3. Consult AWS documentation
4. Check application logs in the Docker container

## License

This infrastructure code is provided as-is for educational and development purposes.
