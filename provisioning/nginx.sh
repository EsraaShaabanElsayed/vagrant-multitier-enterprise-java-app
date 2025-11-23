#!/bin/bash

#===========================================
# Nginx Installation and Configuration
# With HTTPS/SSL Support
#===========================================

echo "==================================="
echo "Installing and Configuring Nginx"
echo "==================================="

# Update system
apt-get update
apt-get install -y nginx openssl

# Create SSL certificates directory and generate certificates
echo "Generating SSL certificates..."
bash -c "$(cat <<'CERT_SCRIPT'
#!/bin/bash
mkdir -p /etc/nginx/ssl
cd /etc/nginx/ssl

# Generate private key
openssl genrsa -out nginx-selfsigned.key 2048

# Generate self-signed certificate (valid for 1 year)
openssl req -new -x509 -key nginx-selfsigned.key \
    -out nginx-selfsigned.crt \
    -days 365 \
    -subj "/C=EG/ST=Cairo/L=Cairo/O=VagrantApp/OU=IT/CN=192.168.56.11/emailAddress=admin@vapp.local"

# Generate Diffie-Hellman parameters
openssl dhparam -out dhparam.pem 2048

# Set permissions
chmod 600 nginx-selfsigned.key
chmod 644 nginx-selfsigned.crt
chmod 644 dhparam.pem

echo "SSL certificates created successfully!"
CERT_SCRIPT
)"

# Remove default configuration
rm -f /etc/nginx/sites-enabled/default

# Create new reverse proxy configuration with HTTPS
cat > /etc/nginx/sites-available/java-app <<'EOF'
# Upstream backend (Tomcat)
upstream tomcat_backend {
    server 192.168.56.12:8080;
}

# HTTP Server - Redirect to HTTPS
server {
    listen 80;
    server_name 192.168.56.11 _;

    # Redirect all HTTP traffic to HTTPS
    return 301 https://$host$request_uri;
}

# HTTPS Server
server {
    listen 443 ssl http2;
    server_name 192.168.56.11 _;

    # SSL Certificate Configuration
    ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;
    ssl_dhparam /etc/nginx/ssl/dhparam.pem;

    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # SSL Session Configuration
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/java-app-access.log;
    error_log /var/log/nginx/java-app-error.log;

    # Main application proxy
    location / {
        proxy_pass http://tomcat_backend;
        
        # Proxy Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Health check endpoint
    location /nginx-health {
        access_log off;
        return 200 "Nginx is healthy and running with HTTPS\n";
        add_header Content-Type text/plain;
    }

    # Static content caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        proxy_pass http://tomcat_backend;
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

# Enable the site
ln -s /etc/nginx/sites-available/java-app /etc/nginx/sites-enabled/

# Test Nginx configuration
echo "Testing Nginx configu ration..."
nginx -t

if [ $? -eq 0 ]; then
    echo "Nginx configuration is valid!"
    
    # Restart Nginx
    systemctl restart nginx
    systemctl enable nginx
    
    echo ""
    echo "==================================="
    echo "Nginx installation complete!"
    echo "==================================="
    echo "HTTP:  http://192.168.56.11"
    echo "HTTPS: https://192.168.56.11"
    echo ""
    echo "HTTP requests will automatically redirect to HTTPS"
    echo ""
    echo "Certificate Details:"
    echo "  - Self-signed certificate (valid for 365 days)"
    echo "  - Location: /etc/nginx/ssl/"
    echo ""
    echo "Note: Your browser will show a security warning"
    echo "      because this is a self-signed certificate."
    echo "      Click 'Advanced' and 'Proceed' to continue."
    echo "==================================="
else
    echo "ERROR: Nginx configuration test failed!"
    exit 1
fi