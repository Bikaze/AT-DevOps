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
export DB_HOST="ecommerce-db.c9qekwasm7wd.eu-west-1.rds.amazonaws.com"
export DB_USER="dbadmin"
export DB_PASS="YourStrongPassword123!"
export DB_NAME="mydatabase"

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
