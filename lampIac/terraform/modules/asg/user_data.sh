#!/bin/bash
# Simple User Data script for LAMP application
set -e

# Create a setup log file
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting LAMP stack setup at $(date)"

# Update system and install prerequisites
apt-get update
apt-get install -y curl

# Install Docker using the official convenience script
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Start Docker
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Run Docker without waiting (it should be ready almost immediately after systemctl enable)
echo "Starting Docker service..."
systemctl is-active --quiet docker || true

# Install netcat for database check
apt-get install -y netcat-openbsd

# Check database connectivity more robustly
echo "Checking database connectivity to ${db_host}..."
db_connected=false
max_attempts=20  # Increase the maximum number of attempts
attempt=1

while [ $attempt -le $max_attempts ]; do
    if nc -z -w1 ${db_host} 3306; then
        echo "Database is ready!"
        db_connected=true
        break
    fi
    echo "Waiting for database... (Attempt $attempt/$max_attempts)"
    sleep 3  # Wait a bit longer between attempts
    ((attempt++))
done

# Continue even if DB isn't reachable yet
if [ "$db_connected" = false ]; then
    echo "Warning: Could not connect to database after $max_attempts attempts, but continuing..."
fi

echo "Starting LAMP application..."

# Pull and run the container
echo "Pulling Docker image..."
docker pull bikaze/lamp

echo "Starting Docker container..."
# Run the LAMP container with environment variables
docker run -d \
  --name lamp-app \
  -p 80:80 \
  -e DB_HOST="${db_host}" \
  -e DB_NAME="${db_name}" \
  -e DB_USER="${db_user}" \
  -e DB_PASSWORD="${db_password}" \
  -e APP_NAME="${app_name}" \
  -e PROJECT_ENV="${environment}" \
  --restart unless-stopped \
  bikaze/lamp

# Verify that the container is running
echo "Verifying container status..."
if [ "$(docker inspect -f {{.State.Running}} lamp-app 2>/dev/null)" != "true" ]; then
    echo "Error: Container is not running properly!"
    docker logs lamp-app
else
    echo "Container is running properly"
fi

# Wait for Apache to be ready to serve requests
echo "Waiting for Apache to be ready..."
max_attempts=20
attempt=1
web_ready=false

while [ $attempt -le $max_attempts ]; do
    if curl -s -f http://localhost:80/ > /dev/null; then
        echo "Web server is responding correctly"
        web_ready=true
        break
    fi
    echo "Waiting for web server... (Attempt $attempt/$max_attempts)"
    sleep 2
    ((attempt++))
done

if [ "$web_ready" = true ]; then
    echo "Application successfully initialized at $(date)"
else
    echo "Warning: Web server did not respond in time, but initialization will continue..."
fi

echo "Application startup complete at $(date)"
