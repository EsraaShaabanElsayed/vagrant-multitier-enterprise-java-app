#!/bin/bash

set -e

# This script runs on EC2 Ubuntu instance at first boot
# It installs Java 8, Tomcat 9, clones the vprofile project, builds it, and deploys

# ------------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------------
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "Starting Tomcat Setup on Ubuntu"
echo "Time: $(date)"
echo "=========================================="

# ------------------------------------------------------------------
# UPDATE SYSTEM & INSTALL PREREQUISITES
# ------------------------------------------------------------------
echo "Updating system packages..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

echo "Installing Java 8, Maven, Git, and utilities..."
apt-get install -y openjdk-8-jdk maven git wget curl netcat unzip mysql-client

# Set JAVA_HOME for Java 8
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> /etc/profile.d/java.sh
echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile.d/java.sh

# Verify Java version
echo "Java version:"
java -version
echo "JAVA_HOME: $JAVA_HOME"

# ------------------------------------------------------------------
# TOMCAT INSTALLATION
# ------------------------------------------------------------------
echo "Installing Tomcat 9..."
cd /tmp

if [ ! -f "apache-tomcat-9.0.75.tar.gz" ]; then
    wget https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.75/bin/apache-tomcat-9.0.75.tar.gz
fi

tar -xzvf apache-tomcat-9.0.75.tar.gz
mv apache-tomcat-9.0.75 /usr/local/tomcat9

# Create tomcat user
useradd -r -m -U -d /usr/local/tomcat9 -s /bin/false tomcat || true

# Set permissions
chown -R tomcat:tomcat /usr/local/tomcat9
chmod +x /usr/local/tomcat9/bin/*.sh

# Configure Tomcat to use Java 8
echo "Configuring Tomcat to use Java 8..."
cat > /usr/local/tomcat9/bin/setenv.sh << 'SETENV'
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export CATALINA_OPTS="-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
SETENV

chmod +x /usr/local/tomcat9/bin/setenv.sh

# ------------------------------------------------------------------
# CREATE SYSTEMD SERVICE FOR TOMCAT
# ------------------------------------------------------------------
echo "Creating Tomcat systemd service..."
cat > /etc/systemd/system/tomcat.service << 'SERVICE'
[Unit]
Description=Apache Tomcat 9 Web Application Container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64"
Environment="CATALINA_PID=/usr/local/tomcat9/temp/tomcat.pid"
Environment="CATALINA_HOME=/usr/local/tomcat9"
Environment="CATALINA_BASE=/usr/local/tomcat9"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

ExecStart=/usr/local/tomcat9/bin/startup.sh
ExecStop=/usr/local/tomcat9/bin/shutdown.sh

RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
# ------------------------------------------------------------------
# TEST CONNECTIVITY TO BACKEND SERVICES
# ------------------------------------------------------------------
echo "=========================================="
echo "Testing connectivity to backend services..."
echo "=========================================="

test_connection() {
    local host=$1
    local port=$2
    local service=$3
    local max_retries=15
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if timeout 10 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
            echo "✓ $service ($host:$port) is reachable"
            return 0
        else
            retry=$((retry + 1))
            if [ $retry -lt $max_retries ]; then
                echo "⟳ Attempt $retry/$max_retries: $service ($host:$port) not ready, retrying in 20s..."
                sleep 20
            fi
        fi
    done
    
    echo "✗ ERROR: $service ($host:$port) is NOT reachable after $max_retries attempts"
    return 1
}

# Extract host and port from endpoints
DB_HOST=$(echo "${db_endpoint}" | cut -d: -f1)
DB_PORT=$(echo "${db_endpoint}" | cut -d: -f2)

echo ""
echo "Backend Service Endpoints:"
echo "  Database: $DB_HOST:$DB_PORT"
echo "  Memcached: ${memcached_endpoint}:11211"
echo "  RabbitMQ: ${rabbitmq_endpoint}:5671"
echo ""

# Test all connections
DB_OK=0
MC_OK=0
RMQ_OK=0

if test_connection "$DB_HOST" "$DB_PORT" "MySQL Database"; then
    DB_OK=1
fi

if test_connection "${memcached_endpoint}" "11211" "Memcached"; then
    MC_OK=1
fi

if test_connection "${rabbitmq_endpoint}" "5671" "RabbitMQ (AMQPS)"; then
    RMQ_OK=1
fi

echo ""
echo "=========================================="
echo "Connectivity Test Summary:"
echo "=========================================="
echo "MySQL Database:  $([ $DB_OK -eq 1 ] && echo '✓ PASS' || echo '✗ FAIL')"
echo "Memcached:       $([ $MC_OK -eq 1 ] && echo '✓ PASS' || echo '✗ FAIL')"
echo "RabbitMQ:        $([ $RMQ_OK -eq 1 ] && echo '✓ PASS' || echo '✗ FAIL')"
echo "=========================================="

# Fail deployment if critical services are unreachable
if [ $DB_OK -eq 0 ] || [ $MC_OK -eq 0 ] || [ $RMQ_OK -eq 0 ]; then
    echo ""
    echo "✗ ERROR: Some backend services are unreachable!"
    echo "Cannot proceed with deployment."
    echo "Check Security Groups and ensure services are in the same VPC."
    exit 1
fi
# ------------------------------------------------------------------
# CLONE VPROFILE PROJECT
# ------------------------------------------------------------------
REPO_URL="https://github.com/EsraaShaabanElsayed/vagrant-multitier-enterprise-java-app.git"
PROJECT_DIR="/tmp/vprofile-project"

echo "Cloning vprofile source code from $REPO_URL..."
rm -rf $PROJECT_DIR
git clone $REPO_URL $PROJECT_DIR

cd $PROJECT_DIR
# ------------------------------------------------------------------
# VERIFY DNS RESOLUTION
# ------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Verifying DNS Resolution..."
echo "=========================================="

for host in "$DB_HOST" "${memcached_endpoint}" "${rabbitmq_endpoint}"; do
    if nslookup "$host" > /dev/null 2>&1; then
        echo "✓ DNS resolves: $host"
    else
        echo "✗ DNS FAILED: $host"
    fi
done
# ------------------------------------------------------------------
# INITIALIZE RDS DATABASE
# ------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Initializing RDS Database..."
echo "=========================================="

# Extract hostname from endpoint (remove port if present)
DB_HOST_ONLY=$(echo "${db_endpoint}" | cut -d: -f1)

echo "Database Host: $DB_HOST_ONLY"
echo "Database Name: ${db_name}"
echo "Database User: ${db_username}"

# Check if database is accessible
if mysql -h "$DB_HOST_ONLY" -u "${db_username}" -p"${db_password}" -e "USE ${db_name};" 2>/dev/null; then
    echo "✓ Database connection successful"
    
    # Check if tables already exist
    TABLE_COUNT=$(mysql -h "$DB_HOST_ONLY" -u "${db_username}" -p"${db_password}" -D "${db_name}" -se "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${db_name}';")
    
    if [ "$TABLE_COUNT" -gt 0 ]; then
        echo "⚠️  Database already has $TABLE_COUNT tables. Skipping initialization."
    else
        echo "Initializing database with schema and data..."
        if mysql -h "$DB_HOST_ONLY" -u "${db_username}" -p"${db_password}" "${db_name}" < src/main/resources/db_backup.sql; then
            echo "✓ Database initialized successfully!"
        else
            echo "✗ Database initialization failed!"
            exit 1
        fi
    fi
else
    echo "✗ ERROR: Cannot connect to database!"
    echo "Please check:"
    echo "  - Security group allows EC2 to access RDS"
    echo "  - RDS endpoint is correct: $DB_HOST_ONLY"
    echo "  - Database credentials are correct"
    exit 1
fi

echo "=========================================="
echo "Database initialization complete!"
echo "=========================================="
echo ""
# ------------------------------------------------------------------
# CREATE APPLICATION.PROPERTIES
# ------------------------------------------------------------------
echo "Updating application.properties with AWS service endpoints..."

# Update JDBC Configuration
sed -i "s|^jdbc.driverClassName=.*|jdbc.driverClassName=org.mariadb.jdbc.Driver|" src/main/resources/application.properties
sed -i "s|^jdbc.url=.*|jdbc.url=jdbc:mariadb://${db_endpoint}/${db_name}?useUnicode=true\&characterEncoding=UTF-8\&zeroDateTimeBehavior=convertToNull|" src/main/resources/application.properties
sed -i "s|^jdbc.username=.*|jdbc.username=${db_username}|" src/main/resources/application.properties
sed -i "s|^jdbc.password=.*|jdbc.password=${db_password}|" src/main/resources/application.properties

# Update Memcached Configuration
sed -i "s|^memcached.active.host=.*|memcached.active.host=${memcached_endpoint}|" src/main/resources/application.properties
sed -i "s|^memcached.standBy.host=.*|memcached.standBy.host=${memcached_endpoint}|" src/main/resources/application.properties

# Update RabbitMQ Configuration
sed -i "s|^rabbitmq.address=.*|rabbitmq.address=${rabbitmq_endpoint}|" src/main/resources/application.properties
sed -i "s|^rabbitmq.username=.*|rabbitmq.username=${rabbitmq_username}|" src/main/resources/application.properties
sed -i "s|^rabbitmq.password=.*|rabbitmq.password=${rabbitmq_password}|" src/main/resources/application.properties

# Update Spring Datasource Configuration (if present)
sed -i "s|^spring.datasource.url=.*|spring.datasource.url=jdbc:mariadb://${db_endpoint}/${db_name}?useUnicode=true\&characterEncoding=UTF-8\&zeroDateTimeBehavior=convertToNull|" src/main/resources/application.properties
sed -i "s|^spring.datasource.username=.*|spring.datasource.username=${db_username}|" src/main/resources/application.properties
sed -i "s|^spring.datasource.password=.*|spring.datasource.password=${db_password}|" src/main/resources/application.properties
sed -i "s|^spring.datasource.driver-class-name=.*|spring.datasource.driver-class-name=org.mariadb.jdbc.Driver|" src/main/resources/application.properties

echo "application.properties updated successfully!"
cat src/main/resources/application.properties

# ------------------------------------------------------------------
# BUILD APPLICATION WITH MAVEN
# ------------------------------------------------------------------
echo "Building application with Maven..."
cd $PROJECT_DIR

# Set Maven options
export MAVEN_OPTS="-Xmx512m"

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

# Clean webapps directory
rm -rf /usr/local/tomcat9/webapps/*
rm -rf /usr/local/tomcat9/work/*
rm -rf /usr/local/tomcat9/temp/*
rm -rf /usr/local/tomcat9/logs/*

# Deploy WAR as ROOT.war
echo "Copying WAR file to Tomcat webapps..."
cp $WAR_FILE /usr/local/tomcat9/webapps/ROOT.war

# Set proper permissions
chown -R tomcat:tomcat /usr/local/tomcat9

# ------------------------------------------------------------------
# START TOMCAT
# ------------------------------------------------------------------
echo "Starting Tomcat service..."
systemctl enable tomcat
systemctl start tomcat

# Wait for deployment
echo "Waiting for application to deploy (this may take 30-60 seconds)..."
DEPLOY_CHECK=0
for i in {1..60}; do
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
if systemctl is-active --quiet tomcat; then
    echo "✓ Tomcat service is running"
else
    echo "✗ ERROR: Tomcat failed to start"
    systemctl status tomcat
    exit 1
fi

# ------------------------------------------------------------------
# DISPLAY STATUS
# ------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Tomcat Setup Complete!"
echo "=========================================="
echo "Time: $(date)"
echo ""
echo "Application accessible via ALB"
echo "Tomcat running on port 8080"
echo ""
echo "Backend connections:"
echo "  - Database: ${db_endpoint}"
echo "  - Memcached: ${memcached_endpoint}:11211"
echo "  - RabbitMQ: ${rabbitmq_endpoint}:5671"
echo ""
echo "Java version in use:"
/usr/local/tomcat9/bin/version.sh | grep "JVM Version"
echo ""
echo "Deployed files:"
ls -lh /usr/local/tomcat9/webapps/
echo ""
echo "=========================================="
echo "Last 50 lines of Tomcat logs:"
echo "=========================================="
tail -50 /usr/local/tomcat9/logs/catalina.out
echo ""
echo "=========================================="
echo "Setup script completed successfully!"
echo "=========================================="