FROM nginx:latest

# Install OpenSSL
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# Create SSL directory
RUN mkdir -p /etc/nginx/ssl

# Generate self-signed certificate
RUN openssl genrsa -out /etc/nginx/ssl/nginx-selfsigned.key 2048 && \
    openssl req -new -x509 -key /etc/nginx/ssl/nginx-selfsigned.key \
    -out /etc/nginx/ssl/nginx-selfsigned.crt \
    -days 365 \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=vprofile/emailAddress=admin@vprofile.local" && \
    openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048

# Set permissions
RUN chmod 600 /etc/nginx/ssl/nginx-selfsigned.key && \
    chmod 644 /etc/nginx/ssl/nginx-selfsigned.crt && \
    chmod 644 /etc/nginx/ssl/dhparam.pem

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
