#!/bin/bash

# ==================================================================
# AWS USER DATA SCRIPT FOR TOMCAT APPLICATION
# ==================================================================
# This script is designed to be used as AWS User Data.
# It installs Java, Tomcat, builds the application, and deploys it.
#
# IMPORTANT: YOU MUST REPLACE THE VARIABLES BELOW WITH YOUR ACTUAL AWS ENDPOINTS
# ==================================================================

# --- CONFIGURATION VARIABLES ---
# Replace these with your RDS Endpoint, ElastiCache Endpoint, and Amazon MQ Endpoint
DB_HOST="cp8c6soo4l7e.us-east-1.rds.amazonaws.com"   # e.g., database-1.xxxx.us-east-1.rds.amazonaws.com
DB_PORT="3306"
DB_NAME="accounts"
DB_USER="appuser"                    # Your RDS Master Username
DB_PASS="app123456789"                 # Your RDS Master Password

MC_HOST="java-app-memcached.6lvylr.cfg.use1.cache.amazonaws.com" # e.g., my-cache.xxxx.0001.use1.cache.amazonaws.com
MC_PORT="11211"

RMQ_HOST="b-352b6ca1-aede-4076-b61c-0ac37e4177ac.mq.us-east-1.on.aws"  # e.g., b-xxxx-xxxx.mq.us-east-1.amazonaws.com
RMQ_PORT="5671"
RMQ_USER="test"
RMQ_PASS="app123456789"

# Repo URL
REPO_URL="https://github.com/EsraaShaabanElsayed/vagrant-multitier-enterprise-java-app.git"
PROJECT_DIR="/tmp/vprofile-project"

# ==================================================================

set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting User Data Script..."

# ------------------------------------------------------------------
# 1. UPDATE SYSTEM & INSTALL PRE-REQUISITES
# ------------------------------------------------------------------
echo "Updating system and installing prerequisites..."
apt-get update
apt-get install -y openjdk-8-jdk maven git wget netcat-openbsd

# Set JAVA_HOME for Java 8
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" > /etc/profile.d/java.sh
source /etc/profile.d/java.sh

# ------------------------------------------------------------------
# 2. TOMCAT INSTALLATION
# ------------------------------------------------------------------
echo "Installing Tomcat 9..."
cd /tmp
if [ ! -f "apache-tomcat-9.0.75.tar.gz" ]; then
    wget -q https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.75/bin/apache-tomcat-9.0.75.tar.gz
fi

tar -xzvf apache-tomcat-9.0.75.tar.gz
rm -rf /usr/local/tomcat9
mv apache-tomcat-9.0.75 /usr/local/tomcat9
chmod +x /usr/local/tomcat9/bin/*.sh

# Create tomcat user
useradd -r -s /bin/false tomcat 2>/dev/null || true
chown -R tomcat:tomcat /usr/local/tomcat9

# Configure Tomcat to use Java 8
cat > /usr/local/tomcat9/bin/setenv.sh << "EOF"
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export CATALINA_OPTS="-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
EOF
chmod +x /usr/local/tomcat9/bin/setenv.sh

# ------------------------------------------------------------------
# 3. CLONE REPO & CONFIGURE APPLICATION
# ------------------------------------------------------------------
echo "Cloning source code..."
rm -rf $PROJECT_DIR
git clone $REPO_URL $PROJECT_DIR

echo "Configuring application.properties with AWS Endpoints..."
APP_PROP="$PROJECT_DIR/src/main/resources/application.properties"

# Backup original file
cp $APP_PROP $APP_PROP.bak

# Update JDBC Configuration
sed -i "s|^jdbc.url=.*|jdbc.url=jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?useUnicode=true\&characterEncoding=UTF-8\&zeroDateTimeBehavior=convertToNull|g" $APP_PROP
sed -i "s|^jdbc.username=.*|jdbc.username=${DB_USER}|g" $APP_PROP
sed -i "s|^jdbc.password=.*|jdbc.password=${DB_PASS}|g" $APP_PROP

# Update Spring Boot JDBC (if present)
sed -i "s|^spring.datasource.url=.*|spring.datasource.url=jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}|g" $APP_PROP
sed -i "s|^spring.datasource.username=.*|spring.datasource.username=${DB_USER}|g" $APP_PROP
sed -i "s|^spring.datasource.password=.*|spring.datasource.password=${DB_PASS}|g" $APP_PROP

# Update Memcached Configuration
sed -i "s|^memcached.active.host=.*|memcached.active.host=${MC_HOST}|g" $APP_PROP
sed -i "s|^memcached.active.port=.*|memcached.active.port=${MC_PORT}|g" $APP_PROP
# Disable standby in AWS (usually one endpoint) or set to same
sed -i "s|^memcached.standBy.host=.*|memcached.standBy.host=${MC_HOST}|g" $APP_PROP
sed -i "s|^memcached.standBy.port=.*|memcached.standBy.port=${MC_PORT}|g" $APP_PROP

# Update Spring Boot Memcached (if present)
sed -i "s|^memcached.servers=.*|memcached.servers=${MC_HOST}:${MC_PORT}|g" $APP_PROP

# Update RabbitMQ Configuration
sed -i "s|^rabbitmq.address=.*|rabbitmq.address=${RMQ_HOST}|g" $APP_PROP
sed -i "s|^rabbitmq.port=.*|rabbitmq.port=${RMQ_PORT}|g" $APP_PROP
sed -i "s|^rabbitmq.username=.*|rabbitmq.username=${RMQ_USER}|g" $APP_PROP
sed -i "s|^rabbitmq.password=.*|rabbitmq.password=${RMQ_PASS}|g" $APP_PROP

# Update Spring Boot RabbitMQ (if present)
sed -i "s|^spring.rabbitmq.host=.*|spring.rabbitmq.host=${RMQ_HOST}|g" $APP_PROP
sed -i "s|^spring.rabbitmq.port=.*|spring.rabbitmq.port=${RMQ_PORT}|g" $APP_PROP
sed -i "s|^spring.rabbitmq.username=.*|spring.rabbitmq.username=${RMQ_USER}|g" $APP_PROP
sed -i "s|^spring.rabbitmq.password=.*|spring.rabbitmq.password=${RMQ_PASS}|g" $APP_PROP

echo "Configuration updated. Checking file content (sensitive info hidden):"
grep -E "jdbc.url|memcached.active.host|rabbitmq.address" $APP_PROP

# ------------------------------------------------------------------
# 4. BUILD ARTIFACT (WAR)
# ------------------------------------------------------------------
echo "Building Application with Maven..."
cd $PROJECT_DIR
mvn clean install -DskipTests

WAR_FILE=$(find target -name "*.war" | head -n 1)
if [ -z "$WAR_FILE" ]; then
    echo "ERROR: No WAR file found in target directory"
    exit 1
fi

# ------------------------------------------------------------------
# 5. DEPLOY TO TOMCAT
# ------------------------------------------------------------------
echo "Deploying WAR to Tomcat..."

# Stop Tomcat if running
pkill -9 -f tomcat || true
rm -rf /usr/local/tomcat9/webapps/*
cp $WAR_FILE /usr/local/tomcat9/webapps/ROOT.war
chown -R tomcat:tomcat /usr/local/tomcat9

# ------------------------------------------------------------------
# 6. SYSTEMD SERVICE
# ------------------------------------------------------------------
echo "Creating systemd service..."
cat > /etc/systemd/system/tomcat9.service << EOF
[Unit]
Description=Apache Tomcat 9
After=network.target

[Service]
Type=forking
User=tomcat
Group=tomcat
Environment=JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
Environment=CATALINA_PID=/usr/local/tomcat9/temp/tomcat.pid
Environment=CATALINA_HOME=/usr/local/tomcat9
Environment=CATALINA_BASE=/usr/local/tomcat9
ExecStart=/usr/local/tomcat9/bin/startup.sh
ExecStop=/usr/local/tomcat9/bin/shutdown.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable tomcat9
systemctl start tomcat9



echo "User Data Script Completed Successfully!"
