# Multi-Tier Enterprise Java Application with Vagrant

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Vagrant](https://img.shields.io/badge/Vagrant-2.2%2B-blue)](https://www.vagrantup.com/)
[![VirtualBox](https://img.shields.io/badge/VirtualBox-6.1%2B-orange)](https://www.virtualbox.org/)

A production-ready, automated deployment of a multi-tier Java web application using Infrastructure as Code (IaC) principles with Vagrant. This project demonstrates enterprise-level architecture with load balancing, caching, message queuing, and database integration—all automated through provisioning scripts.

## 🏗️ Architecture

This project implements a 5-tier architecture with the following components:

```
┌─────────────┐
│   Nginx     │ ← Load Balancer / Reverse Proxy (Web Tier)
│ 192.168.56.11│
└──────┬──────┘
       │
┌──────▼──────┐
│   Tomcat    │ ← Application Server (App Tier)
│ 192.168.56.12│
└──┬────┬────┬┘
   │    │    │
   │    │    └───────────┐
   │    │                │
┌──▼────▼──┐    ┌────────▼─────┐    ┌──────────────┐
│ MariaDB  │    │  Memcached   │    │  RabbitMQ    │
│192.168.56│    │ 192.168.56.14│    │192.168.56.13 │
│   .15    │    └──────────────┘    └──────────────┘
└──────────┘
(Data Tier)     (Cache Tier)        (Message Queue)
```

## ✨ Features

- **Automated Infrastructure Provisioning**: Complete environment setup with a single `vagrant up` command
- **Multi-VM Configuration**: 5 separate VMs working together as a cohesive system
- **Production-Ready Stack**:
  - **Nginx**: HTTPS/SSL enabled reverse proxy with security headers
  - **Apache Tomcat 9**: Java application server with optimized JVM settings
  - **MariaDB 10**: Relational database with remote access configuration
  - **Memcached**: Distributed caching for performance optimization
  - **RabbitMQ**: Message broker for asynchronous communication
- **Security Features**:
  - Self-signed SSL certificates
  - Firewall configuration
  - Secure database user management
- **Developer-Friendly**:
  - Automated Maven builds
  - Hot deployment
  - Comprehensive logging
  - Easy troubleshooting

## 🚀 Quick Start

### Prerequisites

Ensure you have the following installed on your host machine:

- [Vagrant](https://www.vagrantup.com/downloads) (2.2.0 or higher)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (6.1.0 or higher)
- At least 8GB RAM available for VMs
- At least 20GB free disk space

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/EsraaShaabanElsayed/vagrant-multitier-enterprise-java-app.git
   cd vagrant-multitier-enterprise-java-app
   ```

2. **Start the environment**
   ```bash
   vagrant up
   ```
   
   This command will:
   - Create 5 virtual machines
   - Install all required software
   - Configure services and networking
   - Build and deploy the Java application
   - Takes approximately 15-20 minutes on first run

3. **Access the application**
   - **HTTPS (Recommended)**: https://192.168.56.11
   - **HTTP** (redirects to HTTPS): http://192.168.56.11
   - **Direct Tomcat Access**: http://192.168.56.12:8080

   > **Note**: Your browser will show a security warning for the self-signed certificate. Click "Advanced" → "Proceed" to continue.

## 📋 VM Configuration

| VM Name | Hostname | IP Address | OS | RAM | vCPUs | Services |
|---------|----------|------------|-----|-----|-------|----------|
| web01 | nginx | 192.168.56.11 | Ubuntu 22.04 | 800MB | 1 | Nginx (Reverse Proxy) |
| app01 | tomcat | 192.168.56.12 | CentOS Stream 9 | 4200MB | 1 | Tomcat 9, Maven, Java 8 |
| rmq01 | rmq | 192.168.56.13 | CentOS Stream 9 | 1024MB | 1 | RabbitMQ 3 |
| mc01 | mc | 192.168.56.14 | CentOS Stream 9 | 1024MB | 1 | Memcached |
| db01 | mariadb | 192.168.56.15 | CentOS Stream 9 | 2048MB | 1 | MariaDB 10 |

## 🛠️ Project Structure

```
vagrant-multitier-enterprise-java-app/
├── Vagrantfile                    # VM configuration and orchestration
├── provisioning/
│   ├── nginx.sh                   # Nginx installation with SSL
│   ├── tomcat.sh                  # Tomcat + app deployment
│   ├── mariadb.sh                 # Database server setup
│   ├── init_database.sql          # Database schema initialization
│   ├── rmq.sh                     # RabbitMQ installation
│   └── mc.sh                      # Memcached setup
├── src/                           # Java application source code
│   ├── main/
│   │   ├── java/                  # Java classes
│   │   ├── resources/
│   │   │   └── application.properties  # App configuration
│   │   └── webapp/                # Web resources (JSP, CSS, JS)
│   └── test/                      # Unit tests
├── pom.xml                        # Maven configuration
└── README.md
```

## ⚙️ Configuration

### Database Configuration

Default database credentials (configured in `provisioning/init_database.sql`):

```properties
Database: accounts
Username: appuser
Password: app123
Host: 192.168.56.15:3306
```

### Application Properties

Located at `src/main/resources/application.properties`:

```properties
# Database
spring.datasource.url=jdbc:mysql://192.168.56.15:3306/accounts
spring.datasource.username=appuser
spring.datasource.password=app123

# Memcached
memcached.active.host=192.168.56.14
memcached.active.port=11211

# RabbitMQ
rabbitmq.address=192.168.56.13
rabbitmq.port=5672
rabbitmq.username=test
rabbitmq.password=test
```

### RabbitMQ Management

- **Management UI**: http://192.168.56.13:15672
- **Username**: test
- **Password**: test

## 🔧 Common Operations

### Check VM Status
```bash
vagrant status
```

### SSH into a specific VM
```bash
vagrant ssh nginx    # Web server
vagrant ssh tomcat   # Application server
vagrant ssh mariadb  # Database server
vagrant ssh rmq      # RabbitMQ
vagrant ssh mc       # Memcached
```

### Restart Services

**Nginx**:
```bash
vagrant ssh nginx
sudo systemctl restart nginx
```

**Tomcat**:
```bash
vagrant ssh tomcat
sudo /usr/local/tomcat9/bin/shutdown.sh
sudo /usr/local/tomcat9/bin/startup.sh
```

**MariaDB**:
```bash
vagrant ssh mariadb
sudo systemctl restart mariadb
```

### View Logs

**Tomcat Application Logs**:
```bash
vagrant ssh tomcat
sudo tail -f /usr/local/tomcat9/logs/catalina.out
```

**Nginx Logs**:
```bash
vagrant ssh nginx
sudo tail -f /var/log/nginx/java-app-access.log
sudo tail -f /var/log/nginx/java-app-error.log
```

### Rebuild Application

If you make changes to the Java source code:

```bash
vagrant ssh tomcat
cd /tmp/vprofile-project
mvn clean package
sudo cp target/*.war /usr/local/tomcat9/webapps/ROOT.war
sudo /usr/local/tomcat9/bin/shutdown.sh && sleep 3 && sudo /usr/local/tomcat9/bin/startup.sh
```

### Stop and Destroy VMs

```bash
# Stop all VMs
vagrant halt

# Destroy all VMs (frees up disk space)
vagrant destroy -f

# Destroy specific VM
vagrant destroy mariadb -f
```

## 🐛 Troubleshooting

### Application Not Loading / No CSS

**Problem**: Application loads but appears as plain text without styling.

**Solution**: Restart Nginx and clear browser cache:
```bash
vagrant ssh nginx
sudo systemctl restart nginx
```

### Database Connection Error

**Problem**: `SQLGrammarException` or connection timeout errors.

**Solution**: Verify database is running and tables exist:
```bash
vagrant ssh mariadb
mysql -u appuser -papp123 accounts -e "SHOW TABLES;"
```

### Tomcat Not Starting

**Problem**: Application doesn't deploy.

**Solution**: Check Java version and Tomcat logs:
```bash
vagrant ssh tomcat
java -version  # Should show Java 1.8
sudo tail -100 /usr/local/tomcat9/logs/catalina.out
```

### Network Connectivity Issues

**Problem**: Services can't communicate with each other.

**Solution**: Verify hostname resolution:
```bash
vagrant ssh tomcat
cat /etc/hosts  # Should show all VM IPs
ping -c 2 vprodb
```

## 📚 Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Java | 1.8.0 | Application runtime |
| Spring Boot | 2.x | Application framework |
| Maven | 3.x | Build tool |
| Tomcat | 9.0.75 | Application server |
| Nginx | Latest | Reverse proxy & load balancer |
| MariaDB | 10.x | Relational database |
| Memcached | Latest | Caching layer |
| RabbitMQ | 3.x | Message broker |
| CentOS Stream | 9 | OS for backend services |
| Ubuntu | 22.04 LTS | OS for web server |

