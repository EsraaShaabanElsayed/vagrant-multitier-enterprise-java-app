#!/bin/bash

set -e

echo "=========================================="
echo "Installing RabbitMQ on CentOS 9"
echo "=========================================="

# Update system
echo "Updating system packages..."
sudo dnf update -y

# Install required dependencies
echo "Installing dependencies..."
sudo dnf install -y curl wget gnupg2 socat logrotate

# Import RabbitMQ signing keys
echo "Importing RabbitMQ signing keys..."
sudo rpm --import 'https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc'
sudo rpm --import 'https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key'
sudo rpm --import 'https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key'

# Add Erlang repository
echo "Adding Erlang repository..."
cat > /tmp/rabbitmq-erlang.repo <<'EOF'
[modern-erlang]
name=modern-erlang-el9
baseurl=https://yum1.rabbitmq.com/erlang/el/9/$basearch
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key
gpgcheck=1
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
pkg_gpgcheck=1
autorefresh=1
type=rpm-md

[modern-erlang-noarch]
name=modern-erlang-el9-noarch
baseurl=https://yum1.rabbitmq.com/erlang/el/9/noarch
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key
       https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc
gpgcheck=1
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
pkg_gpgcheck=1
autorefresh=1
type=rpm-md

[modern-erlang-source]
name=modern-erlang-el9-source
baseurl=https://yum1.rabbitmq.com/erlang/el/9/SRPMS
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key
       https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc
gpgcheck=1
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
pkg_gpgcheck=1
autorefresh=1
EOF

sudo mv /tmp/rabbitmq-erlang.repo /etc/yum.repos.d/

# Add RabbitMQ repository
echo "Adding RabbitMQ repository..."
cat > /tmp/rabbitmq.repo <<'EOF'
[rabbitmq-el9]
name=rabbitmq-el9
baseurl=https://yum2.rabbitmq.com/rabbitmq/el/9/$basearch
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key
       https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc
gpgcheck=1
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
pkg_gpgcheck=1
autorefresh=1
type=rpm-md

[rabbitmq-el9-noarch]
name=rabbitmq-el9-noarch
baseurl=https://yum2.rabbitmq.com/rabbitmq/el/9/noarch
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key
       https://github.com/rabbitmq/signing-keys/releases/download/3.0/rabbitmq-release-signing-key.asc
gpgcheck=1
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
pkg_gpgcheck=1
autorefresh=1
type=rpm-md

[rabbitmq-el9-source]
name=rabbitmq-el9-source
baseurl=https://yum2.rabbitmq.com/rabbitmq/el/9/SRPMS
repo_gpgcheck=1
enabled=1
gpgkey=https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key
gpgcheck=0
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
pkg_gpgcheck=1
autorefresh=1
type=rpm-md
EOF

sudo mv /tmp/rabbitmq.repo /etc/yum.repos.d/

# Update package metadata
echo "Updating package metadata..."
sudo dnf makecache -y --disablerepo='*' --enablerepo='modern-erlang*'
sudo dnf makecache -y --disablerepo='*' --enablerepo='rabbitmq*'

# Install Erlang
echo "Installing Erlang..."
sudo dnf install -y erlang

# Install RabbitMQ
echo "Installing RabbitMQ..."
sudo dnf install -y rabbitmq-server

# Enable and start RabbitMQ
echo "Enabling and starting RabbitMQ service..."
sudo systemctl enable rabbitmq-server
sudo systemctl start rabbitmq-server

# Enable RabbitMQ management plugin
echo "Enabling RabbitMQ management plugin..."
sudo rabbitmq-plugins enable rabbitmq_management

# Create admin user
echo "Creating admin user..."
sudo rabbitmqctl add_user admin admin123
sudo rabbitmqctl set_user_tags admin administrator
sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"

# Configure firewall (if firewalld is running)
if systemctl is-active --quiet firewalld; then
    echo "Configuring firewall..."
    sudo firewall-cmd --permanent --add-port=5672/tcp
    sudo firewall-cmd --permanent --add-port=15672/tcp
    sudo firewall-cmd --reload
fi

# Display status
echo "=========================================="
echo "RabbitMQ Installation Complete!"
echo "=========================================="
sudo systemctl status rabbitmq-server --no-pager
echo ""
echo "Management UI: http://localhost:15672"
echo "Username: admin"
echo "Password: admin123"
echo ""
echo "AMQP Port: 5672"
echo "=========================================="