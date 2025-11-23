#!/bin/bash

#===========================================
# Apache Tomcat Installation and Configuration
# Customized for Multi-Tier Java Application
#===========================================

echo "==================================="
echo "Installing Apache Tomcat 9"
echo "==================================="

# Update system
apt-get update
apt-get install -y openjdk-11-jdk wget curl

# Verify Java installation
echo "Java version:"
java -version

# Variables
TOMCAT_VERSION="9.0.82"
TOMCAT_HOME="/opt/tomcat"
TOMCAT_USER="tomcat"

# Download and install Tomcat
echo "Downloading Tomcat ${TOMCAT_VERSION}..."
cd /tmp
wget -q https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz

# Extract Tomcat
echo "Extracting Tomcat..."
tar xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
mv apache-tomcat-${TOMCAT_VERSION} ${TOMCAT_HOME}

# Create tomcat user
echo "Creating tomcat user..."
useradd -r -m -U -d ${TOMCAT_HOME} -s /bin/false ${TOMCAT_USER} 2>/dev/null || true

# Set proper permissions
echo "Setting permissions..."
chown -R ${TOMCAT_USER}:${TOMCAT_USER} ${TOMCAT_HOME}
chmod +x ${TOMCAT_HOME}/bin/*.sh

# Configure Tomcat server.xml
echo "Configuring Tomcat server.xml..."
cat > ${TOMCAT_HOME}/conf/server.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLogValve" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

  <GlobalNamingResources>
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>

  <Service name="Catalina">
    <!-- HTTP Connector - Optimized for your project -->
    <Connector port="8080" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443"
               maxThreads="150"
               minSpareThreads="25"
               enableLookups="false"
               acceptCount="100"
               compression="on"
               compressionMinSize="2048"
               compressibleMimeType="text/html,text/xml,text/plain,text/css,text/javascript,application/javascript,application/json,application/xml"
               URIEncoding="UTF-8" />

    <Engine name="Catalina" defaultHost="localhost">
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <Host name="localhost" appBase="webapps"
            unpackWARs="true" autoDeploy="true">

        <!-- Access Log with detailed information -->
        <Valve className="org.apache.catalina.valves.AccessLogValve"
               directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b %D %{User-Agent}i" />

        <Valve className="org.apache.catalina.valves.ErrorReportValve"
               showReport="false"
               showServerInfo="false" />

      </Host>
    </Engine>
  </Service>
</Server>
EOF

# Configure tomcat-users.xml
echo "Configuring Tomcat users..."
cat > ${TOMCAT_HOME}/conf/tomcat-users.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">

  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <role rolename="admin-gui"/>
  <role rolename="admin-script"/>

  <user username="admin" 
        password="admin123" 
        roles="manager-gui,manager-script,manager-jmx,manager-status,admin-gui,admin-script"/>

  <user username="deployer" 
        password="deployer123" 
        roles="manager-script"/>

</tomcat-users>
EOF

# Configure Manager App - Allow remote access
echo "Configuring Manager app..."
cat > ${TOMCAT_HOME}/webapps/manager/META-INF/context.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <!-- Allow access from Nginx and host machine -->
  <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|org\.apache\.catalina\.filters\.CsrfPreventionFilter\$LruCache(?:\$1)?|java\.util\.(?:Linked)?HashMap"/>
</Context>
EOF

# Configure Host Manager App - Allow remote access
cat > ${TOMCAT_HOME}/webapps/host-manager/META-INF/context.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <CookieProcessor className="org.apache.tomcat.util.http.Rfc6265CookieProcessor"
                   sameSiteCookies="strict" />
  <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|org\.apache\.catalina\.filters\.CsrfPreventionFilter\$LruCache(?:\$1)?|java\.util\.(?:Linked)?HashMap"/>
</Context>
EOF


# Create systemd service
echo "Creating systemd service..."
cat > /etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64"
Environment="CATALINA_PID=${TOMCAT_HOME}/temp/tomcat.pid"
Environment="CATALINA_HOME=${TOMCAT_HOME}"
Environment="CATALINA_BASE=${TOMCAT_HOME}"

ExecStart=${TOMCAT_HOME}/bin/startup.sh
ExecStop=${TOMCAT_HOME}/bin/shutdown.sh

User=${TOMCAT_USER}
Group=${TOMCAT_USER}
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Fix ownership
chown -R ${TOMCAT_USER}:${TOMCAT_USER} ${TOMCAT_HOME}

# Reload systemd
systemctl daemon-reload

# Start Tomcat
echo "Starting Tomcat..."
systemctl start tomcat
systemctl enable tomcat

# Wait for startup
echo "Waiting for Tomcat to start..."
sleep 15

# Verify
if systemctl is-active --quiet tomcat; then
    echo ""
    echo "==================================="
    echo "✅ Tomcat installation complete!"
    echo "==================================="
    echo "Version: ${TOMCAT_VERSION}"
    echo "Location: ${TOMCAT_HOME}"
    echo ""
    echo "🌐 Access URLs:"
    echo "  Application:  http://192.168.56.12:8080"
    echo "  Via Nginx:    https://192.168.56.11"
    echo "  Manager GUI:  http://192.168.56.12:8080/manager"
    echo ""
    echo "🔑 Credentials:"
    echo "  Username: admin"
    echo "  Password: admin123"
    echo ""
    echo "📦 Deploy your WAR:"
    echo "  sudo cp your-app.war ${TOMCAT_HOME}/webapps/"
    echo ""
    echo "📊 Useful commands:"
    echo "  Status:  sudo systemctl status tomcat"
    echo "  Logs:    sudo tail -f ${TOMCAT_HOME}/logs/catalina.out"
    echo "  Restart: sudo systemctl restart tomcat"
    echo "==================================="
else
    echo "❌ ERROR: Tomcat failed to start!"
    echo "Check logs: sudo journalctl -u tomcat -n 50"
    exit 1
fi