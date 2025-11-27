#!/bin/bash
set -e

# Define default values if not provided
DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-3306}
DB_NAME=${DB_NAME:-accounts}
DB_USER=${DB_USER:-admin}
DB_PASSWORD=${DB_PASSWORD:-admin123}

MEMCACHED_HOST=${MEMCACHED_HOST:-memcached}
MEMCACHED_PORT=${MEMCACHED_PORT:-11211}

RABBITMQ_HOST=${RABBITMQ_HOST:-rabbitmq}
RABBITMQ_PORT=${RABBITMQ_PORT:-5672}
RABBITMQ_USER=${RABBITMQ_USER:-guest}
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD:-guest}

APP_PROPS_FILE="/usr/local/tomcat/webapps/ROOT/WEB-INF/classes/application.properties"

echo "Configuring application.properties..."

# We need to wait for the WAR to be extracted or modify the properties in the WAR/classpath before startup.
# Since Tomcat extracts WARs on startup, modifying the file inside the WAR or the extracted folder is tricky in a simple entrypoint
# if we want to do it *before* Tomcat starts.
# However, we can modify the file in the classpath if we exploded the WAR or if we rely on Tomcat to extract it.
# A common pattern for Tomcat is to explode the WAR manually or place config in a common loader path.
# For simplicity in this legacy app, we will extract the WAR, modify properties, and run.

if [ -f "/usr/local/tomcat/webapps/ROOT.war" ]; then
    echo "Exploding ROOT.war..."
    mkdir -p /usr/local/tomcat/webapps/ROOT
    cd /usr/local/tomcat/webapps/ROOT
    unzip ../ROOT.war
    rm ../ROOT.war
    cd /usr/local/tomcat
fi

if [ -f "$APP_PROPS_FILE" ]; then
    echo "Found application.properties, injecting configuration..."
    
    # JDBC
    sed -i "s|^jdbc.driverClassName=.*|jdbc.driverClassName=org.mariadb.jdbc.Driver|" $APP_PROPS_FILE
    sed -i "s|^jdbc.url=.*|jdbc.url=jdbc:mariadb://${DB_HOST}:${DB_PORT}/${DB_NAME}?useUnicode=true\&characterEncoding=UTF-8\&zeroDateTimeBehavior=convertToNull|" $APP_PROPS_FILE
    sed -i "s|^jdbc.username=.*|jdbc.username=${DB_USER}|" $APP_PROPS_FILE
    sed -i "s|^jdbc.password=.*|jdbc.password=${DB_PASSWORD}|" $APP_PROPS_FILE

    # Memcached
    sed -i "s|^memcached.active.host=.*|memcached.active.host=${MEMCACHED_HOST}|" $APP_PROPS_FILE
    sed -i "s|^memcached.active.port=.*|memcached.active.port=${MEMCACHED_PORT}|" $APP_PROPS_FILE

    # RabbitMQ
    sed -i "s|^rabbitmq.address=.*|rabbitmq.address=${RABBITMQ_HOST}|" $APP_PROPS_FILE
    sed -i "s|^rabbitmq.port=.*|rabbitmq.port=${RABBITMQ_PORT}|" $APP_PROPS_FILE
    sed -i "s|^rabbitmq.username=.*|rabbitmq.username=${RABBITMQ_USER}|" $APP_PROPS_FILE
    sed -i "s|^rabbitmq.password=.*|rabbitmq.password=${RABBITMQ_PASSWORD}|" $APP_PROPS_FILE
    
    echo "Configuration complete."
else
    echo "WARNING: application.properties not found at $APP_PROPS_FILE"
fi

exec "$@"
