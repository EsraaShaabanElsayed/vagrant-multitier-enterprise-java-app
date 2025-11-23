#!/bin/bash

#===========================================
# Memcached Installation and Configuration
# VM IP: 192.168.56.14
#===========================================

# Exit on error
set -e

# Update system packages
sudo dnf update -y

# Install Memcached
sudo dnf install -y memcached

# Configure Memcached to listen on the VM IP
MEMCACHED_CONF="/etc/sysconfig/memcached"

# Backup original config
sudo cp $MEMCACHED_CONF ${MEMCACHED_CONF}.bak

# Set options: port, user, max connections, memory, listen IP
sudo bash -c "cat > $MEMCACHED_CONF <<EOF
PORT=\"11211\" # Memcached will listen on TCP port 11211.
USER=\"memcached\" # Run Memcached as the memcached user
MAXCONN=\"1024\" # Maximum simultaneous connections.
CACHESIZE=\"64\" # Amount of memory (MB) allocated to Memcached
OPTIONS=\"-l 192.168.56.14\" # Listen on the specific VM IP for network connections.
EOF"

# Enable and start Memcached service
sudo systemctl enable memcached
sudo systemctl start memcached

# Open firewall port 11211 for remote access (optional)
sudo firewall-cmd --permanent --add-port=11211/tcp
sudo firewall-cmd --reload

# Create Memcached client configuration for Java app
CONFIG_FILE="/vagrant/provisioning/memcached.properties"
mkdir -p "$(dirname "$CONFIG_FILE")"
cat > "$CONFIG_FILE" <<EOF
# Memcached configuration for Java application
memcached.servers=192.168.56.14:11211
memcached.protocol=BINARY
memcached.opTimeout=5000
EOF
chmod 644 "$CONFIG_FILE"

echo "Memcached setup complete. Config file created at $CONFIG_FILE"
