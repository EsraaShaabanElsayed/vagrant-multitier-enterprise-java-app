#!/bin/bash


#===========================================
# MariaDB Installation and Configuration
#===========================================

echo "==================================="
echo "Installing and Configuring MariaDB"
echo "==================================="

# Update system packages
dnf update -y

# Install MariaDB server
dnf install -y mariadb-server mariadb

# Enable and start MariaDB service
systemctl enable mariadb
systemctl start mariadb

# Wait a few seconds for MariaDB to initialize
sleep 5

# Secure MariaDB installation (optional)
echo "Securing MariaDB installation..."
mysql_secure_installation <<EOF

y #Set a root password.
app123 #New password:app123
app123 #Re-enter new password:app123
y #Remove anonymous users
y #Disallow root login remotely
y #Remove test database and access to it
y #reload privileges so changes take effect.
EOF

# Create database and user for Java application
echo "Creating database and user..."
mysql -u root -papp123 <<MYSQL_SCRIPT  # connect to MariaDB as the root user with password app123
CREATE DATABASE IF NOT EXISTS appdb CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY 'app123';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "Configuring MariaDB to allow remote connections..."
sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/my.cnf.d/mariadb-server.cnf

# Restart MariaDB to apply changes
systemctl restart mariadb

