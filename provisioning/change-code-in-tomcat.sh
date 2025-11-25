#!/bin/bash
set -e

echo "=== Starting Complete Application Deployment ==="

# 1. Fix git and install dependencies
echo "Installing dependencies..."
sudo apt update
sudo apt install -y net-tools maven git
sudo git config --global --add safe.directory /tmp/vprofile-project

# 2. Clone and build application
echo "Building application..."
cd /tmp
sudo rm -rf vprofile-project
sudo git clone https://github.com/EsraaShaabanElsayed/vagrant-multitier-enterprise-java-app.git vprofile-project
cd vprofile-project

# 3. Build WAR file
sudo mvn clean install -DskipTests

# 4. Stop Tomcat and deploy
echo "Deploying to Tomcat..."
sudo /usr/local/tomcat9/bin/shutdown.sh 2>/dev/null || true
sleep 5
sudo pkill -f tomcat 2>/dev/null || true

# Clean and deploy
sudo rm -rf /usr/local/tomcat9/webapps/*
sudo cp target/*.war /usr/local/tomcat9/webapps/ROOT.war

# 5. Start Tomcat
sudo /usr/local/tomcat9/bin/startup.sh

# 6. Wait and test
echo "Waiting for deployment..."
sleep 30

echo "=== Testing Deployment ==="
curl -I http://localhost:8080/ && echo "✓ Application deployed successfully!" || echo "✗ Deployment failed"

echo "=== Checking Port 8080 ==="
sudo netstat -tlnp | grep 8080 && echo "✓ Tomcat listening on port 8080" || echo "✗ Port 8080 not listening"

echo "=== Deployment Complete ==="