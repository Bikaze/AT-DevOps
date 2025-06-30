# LAMP Stack Infrastructure - Complete Guide

## 🎯 What We've Built

I've created a complete, modular Terraform infrastructure that replaces your shell script with modern Infrastructure as Code practices. Here's what you now have:

### 📁 Project Structure

```
terraform/
├── 📄 main.tf                    # Main orchestration
├── 📄 variables.tf               # Input variables
├── 📄 outputs.tf                 # Output values
├── 📄 terraform.tfvars.example   # Example configuration
├── 📄 README.md                  # Comprehensive documentation
├── 🔧 deploy.sh                  # Automated deployment script
├── 🔧 Makefile                   # Common commands
├── 📄 .gitignore                 # Git ignore rules
└── 📁 modules/                   # Modular components
    ├── 📁 security_groups/       # Network security
    ├── 📁 iam/                   # Identity & access
    ├── 📁 rds/                   # MySQL database
    ├── 📁 alb/                   # Load balancer
    ├── 📁 asg/                   # Auto scaling group
    └── 📁 cloudwatch/            # Monitoring & alarms
```

## 🏗️ Infrastructure Components

### 1. **Auto Scaling Group (ASG)**

- **EC2 Instances**: t2.micro (free tier)
- **Image**: bikaze/lamp Docker container
- **Scaling**: 1-5 instances, starts with 2
- **Health Checks**: ELB-based with 300s grace period

### 2. **Application Load Balancer (ALB)**

- **Type**: Internet-facing Application Load Balancer
- **Health Checks**: HTTP on port 80, path "/"
- **Features**: Sticky sessions, 30s deregistration delay

### 3. **RDS MySQL Database**

- **Engine**: MySQL 8.0
- **Instance**: db.t3.micro (free tier)
- **Storage**: 20GB GP2 (free tier)
- **Networking**: Private subnets, no public access

### 4. **Security Groups**

- **ALB SG**: Allows HTTP/HTTPS from internet
- **App SG**: Allows HTTP from ALB and SSH for debugging
- **RDS SG**: Allows MySQL (3306) from app instances only

### 5. **Auto Scaling Policies**

- **CPU Target Tracking**: Maintains 70% CPU utilization
- **Emergency Step Scaling**: Scales at 85% CPU
- **CloudWatch Alarms**: Monitors CPU, response time, unhealthy hosts

## 🚀 How to Deploy

### Prerequisites Check

```bash
# Verify Terraform is installed
terraform version

# Verify AWS CLI is configured
aws sts get-caller-identity

# Ensure you have an EC2 key pair in eu-west-1
aws ec2 describe-key-pairs --region eu-west-1
```

### Method 1: Using the Automated Script (Recommended)

```bash
cd terraform
./deploy.sh
```

### Method 2: Using Terraform Commands

```bash
cd terraform

# 1. Initialize
terraform init

# 2. Create variables file
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Edit with your values

# 3. Plan deployment
terraform plan

# 4. Apply
terraform apply
```

### Method 3: Using Makefile

```bash
cd terraform
make deploy
```

## ⚙️ Configuration

### Required Variables (terraform.tfvars)

```hcl
# MUST CHANGE THESE:
key_name      = "your-key-pair-name"      # Your EC2 key pair
db_password   = "YourSecurePassword123!"  # Strong database password

# Optional customizations:
project_name     = "php-lamp-app"
environment      = "production"
instance_type    = "t2.micro"
min_size         = 1
max_size         = 5
desired_capacity = 2
```

## 🔧 Terraform Concepts Explained

### What is Terraform?

- **Infrastructure as Code (IaC)**: Define infrastructure using configuration files
- **Declarative**: Describe the desired end state, not the steps
- **State Management**: Tracks actual vs. desired infrastructure
- **Planning**: Shows changes before applying them
- **Modular**: Reusable components for different environments

### Key Terraform Commands

```bash
terraform init      # Initialize project (download providers)
terraform plan      # Show what will be created/changed
terraform apply     # Create/update infrastructure
terraform destroy   # Delete all infrastructure
terraform output    # Show output values
terraform state     # Manage state file
```

### Module Benefits

1. **Reusability**: Use the same module in dev/staging/prod
2. **Organization**: Logical grouping of related resources
3. **Maintainability**: Easier to update and debug
4. **Testing**: Test modules independently
5. **Collaboration**: Teams can work on different modules

## 📊 Monitoring & Management

### Check Infrastructure Status

```bash
# Using the deploy script
./deploy.sh status

# Using Makefile
make status

# Using AWS CLI directly
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names php-lamp-app-asg \
  --region eu-west-1
```

### Application URLs

After deployment, access your application:

- **Main App**: `http://your-alb-dns-name.eu-west-1.elb.amazonaws.com`
- **Health Check**: `http://your-alb-dns-name.eu-west-1.elb.amazonaws.com/health.php`

### CloudWatch Monitoring

- **CPU Utilization**: Auto-scaling based on 70% target
- **ALB Response Time**: Alerts if >2 seconds
- **Unhealthy Hosts**: Alerts if any instance fails health checks
- **Custom Metrics**: Application-specific metrics via CloudWatch agent

## 🔒 Security Features

### Network Security

- **Security Groups**: Least-privilege access rules
- **Private Database**: RDS in private subnets
- **Load Balancer**: Shields instances from direct internet access

### Access Control

- **IAM Roles**: EC2 instances have minimal required permissions
- **No Hard-coded Credentials**: Database credentials via environment variables
- **SSH Access**: Restricted (remove in production)

### Production Recommendations

1. **Remove SSH access** from security groups
2. **Use AWS Secrets Manager** for database passwords
3. **Enable HTTPS** with ACM certificates
4. **Implement WAF** for application firewall
5. **Use private subnets** for application instances

## 🧪 Testing Your Deployment

### Automated Testing

```bash
# Test basic connectivity
ALB_DNS=$(terraform output -raw alb_dns_name)
curl -v http://$ALB_DNS

# Test health endpoint
curl -v http://$ALB_DNS/health.php

# Load testing (optional)
ab -n 1000 -c 10 http://$ALB_DNS/
```

### Manual Testing

1. **Auto Scaling**: Generate CPU load and watch instances scale
2. **High Availability**: Terminate an instance and verify replacement
3. **Database Connectivity**: Check health endpoint shows DB connection

## 🔄 Common Operations

### Updating Infrastructure

```bash
# Modify terraform.tfvars or .tf files
terraform plan    # Review changes
terraform apply   # Apply changes
```

### Scaling Applications

```bash
# Temporarily change desired capacity
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name php-lamp-app-asg \
  --desired-capacity 3 \
  --region eu-west-1
```

### Rolling Updates

```bash
# Update launch template and refresh instances
terraform apply
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name php-lamp-app-asg \
  --region eu-west-1
```

## 🚨 Troubleshooting

### Common Issues

**1. Key Pair Not Found**

```bash
# List available key pairs
aws ec2 describe-key-pairs --region eu-west-1
# Update terraform.tfvars with correct key_name
```

**2. Instances Failing Health Checks**

```bash
# Check instance logs
aws logs describe-log-groups --region eu-west-1
# SSH into instance (if SSH is enabled)
ssh -i your-key.pem ubuntu@instance-ip
```

**3. Database Connection Failures**

```bash
# Verify security group allows port 3306
aws ec2 describe-security-groups --group-ids sg-xxxxx --region eu-west-1
# Check database endpoint
terraform output rds_endpoint
```

**4. Terraform State Issues**

```bash
# Import existing resources
terraform import aws_instance.example i-1234567890abcdef0
# Refresh state
terraform refresh
```

## 💰 Cost Optimization

### Free Tier Usage

- **EC2**: t2.micro instances (750 hours/month)
- **RDS**: db.t3.micro (750 hours/month)
- **ALB**: 15GB data processing/month
- **EBS**: 20GB storage/month

### Cost Monitoring

```bash
# Enable billing alerts in AWS Console
# Use AWS Cost Explorer for analysis
# Consider Reserved Instances for production
```

## 🧹 Cleanup

### Destroy Infrastructure

```bash
# Using deploy script
./deploy.sh destroy

# Using terraform directly
terraform destroy

# Using Makefile
make destroy
```

**⚠️ Warning**: This deletes ALL resources. Ensure you have backups!

## 📚 Next Steps

### Production Readiness

1. **Enable HTTPS**: Add ACM certificate and HTTPS listener
2. **Database Encryption**: Enable encryption at rest
3. **Backup Strategy**: Configure automated RDS backups
4. **Monitoring**: Set up comprehensive CloudWatch dashboards
5. **CI/CD**: Integrate with GitHub Actions or similar

### Environment Management

```bash
# Create separate environments
cp terraform.tfvars terraform-dev.tfvars
cp terraform.tfvars terraform-prod.tfvars

# Deploy to different environments
terraform apply -var-file="terraform-dev.tfvars"
```

## 🆘 Getting Help

### Resources

- **AWS Documentation**: https://docs.aws.amazon.com/
- **Terraform Documentation**: https://terraform.io/docs/
- **Community**: Stack Overflow, HashiCorp Community

### Debug Commands

```bash
# Terraform debugging
export TF_LOG=DEBUG
terraform apply

# AWS CLI debugging
aws --debug ec2 describe-instances

# Infrastructure state
terraform state list
terraform state show aws_instance.example
```

---

**🎉 Congratulations!** You now have a modern, scalable, and maintainable LAMP stack infrastructure using Terraform best practices. The modular design makes it easy to extend, modify, and deploy across different environments.

**Need any clarification or want to customize something specific? Just ask!** 🚀
