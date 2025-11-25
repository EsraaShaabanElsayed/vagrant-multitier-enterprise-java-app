#!/bin/bash

set -e

# ------------------------------------------------------------------
# CLONE REPO & UPDATE APPLICATION.PROPERTIES
# ------------------------------------------------------------------
REPO_URL="https://github.com/EsraaShaabanElsayed/vagrant-multitier-enterprise-java-app.git"
PROJECT_DIR="/tmp/vprofile-project"

echo "Cloning/Updating source code from $REPO_URL..."
if [ -d "$PROJECT_DIR" ]; then
    cd $PROJECT_DIR
    git pull origin main
else
    git clone $REPO_URL $PROJECT_DIR
    cd $PROJECT_DIR
fi


# ------------------------------------------------------------------
# TEST CONNECTIVITY TO AWS SERVICES
# ------------------------------------------------------------------
echo "Testing connectivity to AWS services..."

test_connection() {
    local host=$1
    local port=$2
    local service=$3
    
    if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        echo "✓ $service ($host:$port) is reachable"
        return 0
    else
        echo "✗ WARNING: $service ($host:$port) is NOT reachable"
        return 1
    fi
}

echo "Testing backend connections..."
test_connection "${RDS_ENDPOINT}" "3306" "RDS Database"
test_connection "${ELASTICACHE_ENDPOINT}" "11211" "ElastiCache Memcached"
test_connection "${AMAZON_MQ_ENDPOINT}" "5671" "Amazon MQ RabbitMQ"

echo ""

# ------------------------------------------------------------------
# BUILD ARTIFACT (WAR)
# ------------------------------------------------------------------
echo "Building Application with Maven..."
mvn clean install -DskipTests

# Verify WAR was created
WAR_FILE=$(find target -name "*.war" | head -n 1)
if [ -z "$WAR_FILE" ]; then
    echo "ERROR: No WAR file found in target directory"
    ls -la target/
    exit 1
fi

echo "✓ WAR file created: $WAR_FILE"
ls -lh $WAR_FILE

# ------------------------------------------------------------------
# DEPLOY TO TOMCAT
# ------------------------------------------------------------------
echo "Deploying WAR to Tomcat..."

# Stop Tomcat if running
if pgrep -f tomcat > /dev/null; then
    echo "Stopping existing Tomcat process..."
    /usr/local/tomcat9/bin/shutdown.sh || true
    sleep 5
    # Force kill if still running
    pkill -9 -f tomcat || true
fi

# Clean webapps and work directories
echo "Cleaning Tomcat directories..."
rm -rf /usr/local/tomcat9/webapps/*
rm -rf /usr/local/tomcat9/work/*
rm -rf /usr/local/tomcat9/temp/*
rm -rf /usr/local/tomcat9/logs/*

# Deploy WAR
echo "Copying WAR file to Tomcat..."
cp $WAR_FILE /usr/local/tomcat9/webapps/ROOT.war

# Set proper permissions
chown -R tomcat:tomcat /usr/local/tomcat9 2>/dev/null || true

# Start Tomcat
echo "Starting Tomcat..."
/usr/local/tomcat9/bin/startup.sh

# Wait for deployment
echo "Waiting for application to deploy (this may take 30-60 seconds)..."
DEPLOY_CHECK=0
for i in {1..40}; do
    if [ -d "/usr/local/tomcat9/webapps/ROOT/WEB-INF" ]; then
        echo "✓ Application deployed successfully!"
        DEPLOY_CHECK=1
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

if [ $DEPLOY_CHECK -eq 0 ]; then
    echo "✗ WARNING: Application deployment taking longer than expected"
fi

# Check if Tomcat is running
sleep 5
if pgrep -f tomcat > /dev/null; then
    echo "✓ Tomcat is running (PID: $(pgrep -f tomcat))"
else
    echo "✗ ERROR: Tomcat failed to start"
    exit 1
fi

# ------------------------------------------------------------------
# DISPLAY STATUS AND LOGS
# ------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Application Deployment Complete!"
echo "=========================================="
echo "Application URL: http://$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):8080"
echo "ALB URL: Check AWS Console for your Application Load Balancer DNS"
echo ""
echo "Connected AWS Services:"
echo "  - Database: ${RDS_ENDPOINT}:3306"
echo "  - Memcached: ${ELASTICACHE_ENDPOINT}:11211"
echo "  - RabbitMQ: ${AMAZON_MQ_ENDPOINT}:5671"
echo ""
echo "Deployed files:"
ls -lh /usr/local/tomcat9/webapps/
echo ""
echo "=========================================="
echo "Last 20 lines of Tomcat logs:"
echo "=========================================="
tail -20 /usr/local/tomcat9/logs/catalina.out
echo ""
echo "=========================================="
echo "To monitor logs in real-time:"
echo "  tail -f /usr/local/tomcat9/logs/catalina.out"
echo "To check application health:"
echo "  curl -I http://localhost:8080/"
echo "=========================================="