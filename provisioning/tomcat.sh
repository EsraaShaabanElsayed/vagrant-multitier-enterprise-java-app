#!/bin/bash

#===========================================
# Apache Tomcat Installation and Configuration
# For CentOS / RHEL / Rocky / AlmaLinux
#===========================================

echo "==================================="
echo "Installing Apache Tomcat 9 on CentOS"
echo "==================================="

# Update system
yum update -y
yum install -y java-11-openjdk java-11-openjdk-devel wget curl tar

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

echo "Extracting Tomcat..."
tar xzf apache-tomcat-${TOMCAT_VERSION}.tar.gz
mv apache-tomcat-${TOMCAT_VERSION} ${TOMCAT_HOME}

# Create Tomcat user
echo "Creating tomcat user..."
useradd -r -m -U -d ${TOMCAT_HOME} -s /bin/false ${TOMCAT_USER} 2>/dev/null || true

# Set permissions
echo "Setting permissions..."
chown -R ${TOMCAT_USER}:${TOMCAT_USER} ${TOMCAT_HOME}
chmod +x ${TOMCAT_HOME}/bin/*.sh

# Configure server.xml
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
<tomcat-users>
  <role rolename="manager-gui"/>
  <role rolename="manager-script"/>
  <role rolename="manager-jmx"/>
  <role rolename="manager-status"/>
  <role rolename="admin-gui"/>
  <role rolename="admin-script"/>

  <user username="admin" password="admin123"
        roles="manager-gui,manager-script,manager-jmx,manager-status,admin-gui,admin-script"/>

  <user username="deployer" password="deployer123"
        roles="manager-script"/>
</tomcat-users>
EOF

# Allow remote Manager access
echo "Configuring Manager app..."
mkdir -p ${TOMCAT_HOME}/webapps/manager/META-INF

cat > ${TOMCAT_HOME}/webapps/manager/META-INF/context.xml <<'EOF'
<Context antiResourceLocking="false" privileged="true">
  <CookieProcessor sameSiteCookies="strict" />
  <Manager sessionAttributeValueClassNameFilter="java\.lang\.(?:Boolean|Integer|Long|Number|String)|java\.util\.(?:Linked)?HashMap"/>
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

Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk"
Environment="CATALINA_PID=${TOMCAT_HOME}/temp/tomcat.pid"
Environment="CATALINA_HOME=${TOMCAT_HOME}"
Environment="CATALINA_BASE=${TOMCAT_HOME}"

ExecStart=${TOMCAT_HOME}/bin/startup.sh
ExecStop=${TOMCAT_HOME}/bin/shutdown.sh

User=${TOMCAT_USER}
Group=${TOMCAT_USER}
UMask=0007
Restart=on-failure

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

sleep 15

if systemctl is-active --quiet tomcat; then
    echo ""
    echo "==================================="
    echo "✅ Tomcat installation complete on CentOS!"
    echo "==================================="
    echo "Application: http://<your-ip>:8080"
    echo "Manager GUI: http://<your-ip>:8080/manager"
else
    echo "❌ ERROR: Tomcat failed to start!"
    systemctl status tomcat
    exit 1
fi
