#!/bin/bash

# Memcached Provisioning Script for CentOS
# This script installs and configures Memcached for the multi-tier app
# VM IP: 192.168.56.14

echo "=================================="
echo "Installing Memcached on CentOS..."
echo "=================================="

# Install EPEL repository (Extra Packages for Enterprise Linux)
sudo yum install -y epel-release

# Update package repository
sudo yum update -y

# Install Memcached and dependencies
sudo yum install -y memcached

# Install netcat and net-tools for verification
sudo yum install -y nc net-tools

echo "=================================="
echo "Configuring Memcached..."
echo "=================================="

# Backup original config
sudo cp /etc/sysconfig/memcached /etc/sysconfig/memcached.backup

# Configure Memcached options in /etc/sysconfig/memcached
sudo cat > /etc/sysconfig/memcached <<EOF
PORT="11211"
USER="memcached"
MAXCONN="1024"
CACHESIZE="128"
OPTIONS="-l 0.0.0.0"
EOF

echo "=================================="
echo "Configuring Firewall..."
echo "=================================="

# Allow Memcached through firewall
sudo firewall-cmd --permanent --add-port=11211/tcp
sudo firewall-cmd --reload

echo "=================================="
echo "Starting Memcached Service..."
echo "=================================="

# Enable Memcached to start on boot
sudo systemctl enable memcached

# Start Memcached service
sudo systemctl start memcached

# Check service status
sudo systemctl status memcached --no-pager

echo "=================================="
echo "Verifying Memcached Installation..."
echo "=================================="

# Check if Memcached is listening on port 11211
if sudo netstat -tlnp | grep :11211; then
    echo "✓ Memcached is running on port 11211"
else
    echo "✗ Memcached is NOT running on port 11211"
fi

# Display Memcached stats
echo ""
echo "Memcached Stats:"
echo "stats" | nc 192.168.56.14 11211 | head -10

echo "=================================="
echo "Memcached installation complete!"
echo "=================================="
echo "Memcached is accessible at: 192.168.56.14:11211"
echo "Memory allocated: 128MB"
echo "=================================="