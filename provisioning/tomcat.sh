#!/bin/bash

set -e

# ------------------------------------------------------------------
# 0. HOSTNAME RESOLUTION
# ------------------------------------------------------------------
echo "Adding Host Entries to /etc/hosts..."
# Add all hostnames with proper aliases
sudo bash -c 'cat >> /etc/hosts << EOF
192.168.56.15 vprodb mariadb db01
192.168.56.14 mc mc01
192.168.56.13 rmq rmq01
192.168.56.12 tomcat app01
192.168.56.11 nginx web01
EOF'

echo "Verifying /etc/hosts entries:"
cat /etc/hosts | grep -E "vprodb|mc|rmq|tomcat|nginx"

# ------------------------------------------------------------------
# 1. PRE-REQUISITES - INSTALL JAVA 8
# ------------------------------------------------------------------
echo "Installing Java 8, Maven, Git, and utilities..."
sudo dnf install -y java-1.8.0-openjdk-devel maven git wget nc

# Set JAVA_HOME for Java 8
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
echo "export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk" | sudo tee /etc/profile.d/java.sh
source /etc/profile.d/java.sh

# Verify Java version
echo "Java version:"
java -version
echo "JAVA_HOME: $JAVA_HOME"

# ------------------------------------------------------------------
# 2. TOMCAT INSTALLATION
# ------------------------------------------------------------------
echo "Installing Tomcat 9..."
cd /tmp
if [ ! -f "apache-tomcat-9.0.75.tar.gz" ]; then
    wget https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.75/bin/apache-tomcat-9.0.75.tar.gz
fi

tar -xzvf apache-tomcat-9.0.75.tar.gz


sudo mv apache-tomcat-9.0.75 /usr/local/tomcat9
sudo chmod +x /usr/local/tomcat9/bin/*.sh

# Configure Tomcat to use Java 8
echo "Configuring Tomcat to use Java 8..."
sudo bash -c 'cat > /usr/local/tomcat9/bin/setenv.sh << "EOF"
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk
export CATALINA_OPTS="-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
EOF'
sudo chmod +x /usr/local/tomcat9/bin/setenv.sh

# ------------------------------------------------------------------
# 3. CLONE REPO & FIX APPLICATION.PROPERTIES
# ------------------------------------------------------------------
REPO_URL="https://github.com/EsraaShaabanElsayed/vagrant-multitier-enterprise-java-app.git"
PROJECT_DIR="/tmp/vprofile-project"

echo "Cloning source code from $REPO_URL..."
rm -rf $PROJECT_DIR
git clone $REPO_URL $PROJECT_DIR



# ------------------------------------------------------------------
# 4. TEST CONNECTIVITY TO BACKEND SERVICES
# ------------------------------------------------------------------
echo "Testing connectivity to backend services..."

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

test_connection "vprodb" "3306" "Database"
test_connection "mc" "11211" "Memcached"
test_connection "rmq" "5672" "RabbitMQ"

echo ""

# ------------------------------------------------------------------
# 5. BUILD ARTIFACT (WAR)
# ------------------------------------------------------------------
echo "Building Application with Maven..."
cd $PROJECT_DIR
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
# 6. DEPLOY TO TOMCAT
# ------------------------------------------------------------------
echo "Deploying WAR to Tomcat..."

# Stop Tomcat if running
if pgrep -f tomcat > /dev/null; then
    echo "Stopping existing Tomcat process..."
    sudo /usr/local/tomcat9/bin/shutdown.sh || true
    sleep 5
    # Force kill if still running
    sudo pkill -9 -f tomcat || true
fi

# Clean webapps and work directories
echo "Cleaning Tomcat directories..."
sudo rm -rf /usr/local/tomcat9/webapps/*
sudo rm -rf /usr/local/tomcat9/work/*
sudo rm -rf /usr/local/tomcat9/temp/*
sudo rm -rf /usr/local/tomcat9/logs/*

# Deploy WAR
echo "Copying WAR file to Tomcat..."
sudo cp $WAR_FILE /usr/local/tomcat9/webapps/ROOT.war

# Set proper permissions
sudo chown -R vagrant:vagrant /usr/local/tomcat9 2>/dev/null || sudo chown -R $(whoami):$(whoami) /usr/local/tomcat9

# Start Tomcat
echo "Starting Tomcat with Java 8..."
sudo /usr/local/tomcat9/bin/startup.sh

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
# 7. CONFIGURE FIREWALL
# ------------------------------------------------------------------
if systemctl is-active --quiet firewalld; then
    echo "Configuring firewall for Tomcat..."
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --reload
fi

# ------------------------------------------------------------------
# 8. DISPLAY STATUS AND LOGS
# ------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Tomcat Setup Complete!"
echo "=========================================="
echo "Application URL: http://192.168.56.12:8080"
echo ""
echo "Backend connections:"
echo "  - Database: vprodb:3306 (192.168.56.15)"
echo "  - Memcached: mc:11211 (192.168.56.14)"
echo "  - RabbitMQ: rmq:5672 (192.168.56.13)"
echo ""
echo "Java version in use:"
sudo /usr/local/tomcat9/bin/version.sh | grep "JVM Version"
echo ""
echo "Deployed files:"
ls -lh /usr/local/tomcat9/webapps/
echo ""
echo "=========================================="
echo "Last 40 lines of Tomcat logs:"
echo "=========================================="
sudo tail -40 /usr/local/tomcat9/logs/catalina.out
echo ""
echo "=========================================="
echo "To monitor logs in real-time:"
echo "  sudo tail -f /usr/local/tomcat9/logs/catalina.out"
echo "=========================================="