#!/bin/bash
# AWS CLI Script to create RDS MySQL Database and EC2 instance with bikaze/rds-api image
# This script uses free tier options and default VPC

set -e # Exit on error
echo "Starting AWS deployment script..."

# Configuration variables - adjust these as needed
AWS_REGION="eu-west-1"  # Region with good free tier support
DB_NAME="mydatabase"
DB_USERNAME="dbadmin"
DB_PASSWORD="YourStrongPassword123!"  # CHANGE THIS!
DB_INSTANCE_IDENTIFIER="ecommerce-db"
EC2_NAME="api-server"
EC2_KEY_NAME="bkz-001"  # You'll need to create this key pair beforehand in AWS console

# Create SQL initialization script - removed stored procedures to simplify
cat > db_init.sql << 'EOL'
-- First select the database
USE mydatabase;

-- Drop tables if they exist
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

-- Customers table
CREATE TABLE customers (
  customer_id INT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  country VARCHAR(50)
);

-- Products table
CREATE TABLE products (
  product_id INT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  category VARCHAR(50),
  price DECIMAL(10,2)
);

-- Orders table
CREATE TABLE orders (
  order_id INT PRIMARY KEY,
  customer_id INT,
  order_date DATE,
  status VARCHAR(20),
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Order Items table
CREATE TABLE order_items (
  order_item_id INT PRIMARY KEY,
  order_id INT,
  product_id INT,
  quantity INT,
  unit_price DECIMAL(10,2),
  FOREIGN KEY (order_id) REFERENCES orders(order_id),
  FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Customers
INSERT INTO customers VALUES
(1, 'Alice Smith', 'alice@example.com', 'USA'),
(2, 'Bob Jones', 'bob@example.com', 'Canada'),
(3, 'Charlie Zhang', 'charlie@example.com', 'UK');

-- Products
INSERT INTO products VALUES
(1, 'Laptop', 'Electronics', 1200.00),
(2, 'Smartphone', 'Electronics', 800.00),
(3, 'Desk Chair', 'Furniture', 150.00),
(4, 'Coffee Maker', 'Appliances', 85.50);

-- Orders
INSERT INTO orders VALUES
(1, 1, '2023-11-15', 'Shipped'),
(2, 2, '2023-11-20', 'Pending'),
(3, 1, '2023-12-01', 'Delivered'),
(4, 3, '2023-12-03', 'Cancelled');

-- Order Items
INSERT INTO order_items VALUES
(1, 1, 1, 1, 1200.00), -- Laptop
(2, 1, 4, 2, 85.50),   -- Coffee Maker
(3, 2, 2, 1, 800.00),  -- Smartphone
(4, 3, 3, 2, 150.00),  -- Desk Chair
(5, 4, 1, 1, 1200.00); -- Laptop
EOL

echo "Created database initialization script"

# Create a template user-data script with placeholders
cat > user_data.template.sh << 'EOL'
#!/bin/bash
# Install basic tools
apt-get update -y
apt-get install -y mysql-client awscli

# Install Docker using the official Docker script
curl -o get-docker.sh https://get.docker.com/
bash get-docker.sh
systemctl enable docker
systemctl start docker

# Create a log file to track progress
exec > >(tee -a /var/log/user-data.log) 2>&1
echo "Starting deployment: $(date)"

# Set environment variables
export DB_HOST="__RDS_ENDPOINT__"
export DB_USER="__DB_USERNAME__"
export DB_PASS="__DB_PASSWORD__"
export DB_NAME="__DB_NAME__"

echo "Using RDS endpoint: $DB_HOST"

# Function to wait for the database to become available
wait_for_rds() {
    echo "Checking if RDS is available at $DB_HOST"
    for i in {1..30}; do
        if mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1" > /dev/null 2>&1; then
            echo "RDS is available!"
            return 0
        else
            echo "Waiting for RDS to become available... attempt $i/30"
            sleep 10
        fi
    done
    echo "Failed to connect to RDS after multiple attempts"
    return 1
}

# Wait for database to be fully available
wait_for_rds

# Initialize the database
echo "Initializing database with schema and data"
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" < /tmp/db_init.sql
echo "Database initialization complete"

# Run the application container
echo "Starting application container"
docker pull bikaze/rds-api
docker run -d --name rds-api \
  -p 80:3000 \
  -e DB_HOST="$DB_HOST" \
  -e DB_USER="$DB_USER" \
  -e DB_PASSWORD="$DB_PASS" \
  -e DB_NAME="$DB_NAME" \
  --restart unless-stopped \
  bikaze/rds-api

echo "Setup complete! $(date)"

# Create a status file for monitoring
cat > /home/ubuntu/status.txt << STATUSEOF
Setup completed at: $(date)
RDS Host: $DB_HOST
API Container running: $(docker ps | grep rds-api | wc -l)
API accessible at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
STATUSEOF
EOL

echo "Created user-data template script"

# Step 1: Get the default VPC ID
echo "Getting default VPC information..."

DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query 'Vpcs[0].VpcId' \
  --output text)

if [ -z "$DEFAULT_VPC_ID" ]; then
  echo "Error: No default VPC found. Please create a default VPC or modify the script to use a specific VPC."
  exit 1
fi

echo "Using default VPC: $DEFAULT_VPC_ID"

# Get two subnets from the default VPC in different AZs
SUBNETS=($(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$DEFAULT_VPC_ID" \
  --query 'Subnets[0:2].SubnetId' \
  --output text))

SUBNET1_ID=${SUBNETS[0]}
SUBNET2_ID=${SUBNETS[1]}

echo "Using subnets: $SUBNET1_ID, $SUBNET2_ID"

# Step 2: Create security groups
echo "Creating security groups..."

# RDS Security Group
RDS_SG_ID=$(aws ec2 create-security-group \
  --group-name ecommerce-rds-sg \
  --description "Security group for RDS Database" \
  --vpc-id $DEFAULT_VPC_ID \
  --query 'GroupId' \
  --output text)

echo "Created RDS Security Group: $RDS_SG_ID"

# EC2 Security Group
EC2_SG_ID=$(aws ec2 create-security-group \
  --group-name ecommerce-ec2-sg \
  --description "Security group for EC2 Instance" \
  --vpc-id $DEFAULT_VPC_ID \
  --query 'GroupId' \
  --output text)

echo "Created EC2 Security Group: $EC2_SG_ID"

# Add rules to RDS Security Group - Allow MySQL access from EC2
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG_ID \
  --protocol tcp \
  --port 3306 \
  --source-group $EC2_SG_ID

# Add rules to EC2 Security Group - Allow SSH and HTTP from anywhere
aws ec2 authorize-security-group-ingress \
  --group-id $EC2_SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id $EC2_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Step 3: Create DB Subnet Group
echo "Creating DB Subnet Group..."

aws rds create-db-subnet-group \
  --db-subnet-group-name ecommerce-db-subnet-group \
  --db-subnet-group-description "Subnet group for ecommerce database" \
  --subnet-ids "$SUBNET1_ID" "$SUBNET2_ID"

# Step 4: Create RDS MySQL Instance (Free Tier)
echo "Creating RDS MySQL instance (this may take a while)..."

aws rds create-db-instance \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --db-name $DB_NAME \
  --engine mysql \
  --engine-version 8.0 \
  --db-instance-class db.t3.micro \
  --allocated-storage 20 \
  --storage-type gp2 \
  --master-username $DB_USERNAME \
  --master-user-password $DB_PASSWORD \
  --vpc-security-group-ids $RDS_SG_ID \
  --db-subnet-group-name ecommerce-db-subnet-group \
  --publicly-accessible \
  --backup-retention-period 0 \
  --no-multi-az \
  --no-auto-minor-version-upgrade \
  --copy-tags-to-snapshot

echo "RDS MySQL instance creation initiated - waiting for it to be available..."

# Wait for RDS instance to be available (this can take 5-10 minutes)
echo "Waiting for RDS instance to be available..."
aws rds wait db-instance-available \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER

# Get the RDS endpoint
RDS_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo "RDS instance is now available at: $RDS_ENDPOINT"

# Generate the final user_data.sh from the template by replacing placeholders
cp user_data.template.sh user_data.sh

# Use sed to replace all placeholders with actual values
sed -i "s|__RDS_ENDPOINT__|${RDS_ENDPOINT}|g" user_data.sh
sed -i "s|__DB_USERNAME__|${DB_USERNAME}|g" user_data.sh
sed -i "s|__DB_PASSWORD__|${DB_PASSWORD}|g" user_data.sh
sed -i "s|__DB_NAME__|${DB_NAME}|g" user_data.sh

echo "Generated user_data.sh with actual environment values"

# Step 5: Launch EC2 instance (Free Tier)
echo "Launching EC2 instance..."

# Get latest Ubuntu 20.04 AMI ID (Free Tier eligible)
AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
  --output text)

echo "Using AMI: $AMI_ID"

# Create EC2 instance
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t2.micro \
  --key-name $EC2_KEY_NAME \
  --security-group-ids $EC2_SG_ID \
  --subnet-id $SUBNET1_ID \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$EC2_NAME}]" \
  --user-data file://user_data.sh \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "EC2 instance created: $INSTANCE_ID"

# Wait for EC2 instance to be running
echo "Waiting for EC2 instance to be running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID

# Get EC2 public IP
EC2_PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "EC2 instance is now running at: $EC2_PUBLIC_IP"

# Copy database initialization script to EC2
echo "Copying database initialization script to EC2 instance..."
# Allow some time for SSH to become available
sleep 30
scp -o StrictHostKeyChecking=no db_init.sql ubuntu@${EC2_PUBLIC_IP}:/tmp/

echo "Setup complete!"
echo "====================================="
echo "RDS Endpoint: $RDS_ENDPOINT"
echo "RDS Database Name: $DB_NAME"
echo "RDS Username: $DB_USERNAME"
echo "EC2 Public IP: $EC2_PUBLIC_IP"
echo "API URL: http://$EC2_PUBLIC_IP"  # Port 80 is default HTTP port
echo "====================================="
echo "NOTE: The EC2 instance is still initializing and connecting to the RDS database."
echo "It may take a few minutes before the API becomes available."
echo "You can SSH into the instance to check progress:"
echo "ssh ubuntu@${EC2_PUBLIC_IP}"
echo "Then run: cat /var/log/user-data.log"