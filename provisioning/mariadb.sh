#!/bin/bash

# 1. Install MariaDB
echo "Updating system and installing MariaDB..."
dnf install -y mariadb-server

# 2. Start Service
echo "Starting MariaDB Service..."
systemctl start mariadb
systemctl enable mariadb

# 3. Configure Database & User
# UPDATED: Matches your config file (dbname: accounts, user: appuser)
DB_NAME="accounts"
DB_USER="appuser"
DB_PASS="app123"

echo "Configuring Database: $DB_NAME"

mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

# 4. Configure Remote Access (Bind Address)
echo "Configuring Remote Access..."
# Backup config
cp /etc/my.cnf.d/mariadb-server.cnf /etc/my.cnf.d/mariadb-server.cnf.bak

# Allow 0.0.0.0 (Remote connections)
sed -i 's/^bind-address/#bind-address/' /etc/my.cnf.d/mariadb-server.cnf
echo "[mysqld]" >> /etc/my.cnf.d/mariadb-server.cnf
echo "bind-address=0.0.0.0" >> /etc/my.cnf.d/mariadb-server.cnf

# 5. Restart
systemctl restart mariadb
echo "MariaDB Setup Complete for database: $DB_NAME"

# 6. Initialize Database Schema (NEW!)
echo "Initializing database tables from SQL file..."
mysql -u root $DB_NAME < /vagrant/provisioning/init_database.sql
