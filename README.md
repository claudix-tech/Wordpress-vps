# WordPress Docker VPS Boilerplate

**Production-ready Docker boilerplate for deploying WordPress instances on a VPS**

This repository contains a complete, reusable boilerplate for quickly deploying one or multiple WordPress instances on a VPS with full automation, SSL support, and instance management capabilities.

## ⭐ Features

- 🐳 **Docker & Docker Compose** - Complete containerized WordPress setup
- 🔒 **SSL/HTTPS** - Automatic Let's Encrypt certificate generation and renewal
- 🛡️ **NGINX Reverse Proxy** - Production-grade reverse proxy
- 📊 **PHPMyAdmin** - Database management interface
- 🚀 **Multi-Instance Support** - Deploy multiple WordPress sites from one boilerplate
- 🔄 **Backup & Restore** - Automated backup scripts with database and file support
- 📈 **Scalability** - Easy to scale WordPress containers for high traffic
- 🔐 **Security** - Best practices built-in (strong passwords, environment variables, permissions)
- 🎯 **Easy Deployment** - One-command setup via deployment script
- 📝 **Comprehensive Documentation** - Full guides for development, staging, and production

---

## 🚀 Quick Start - Single Instance

### Prerequisites

- Docker and Docker Compose installed on your VPS
- Ubuntu 22.04 LTS or later (recommended)
- A domain name pointing to your VPS
- Root or sudo access

### One-Line Deployment

```bash
curl -sSL https://raw.githubusercontent.com/yourusername/wordpress-vps/main/deploy.sh | bash
```

Or clone and deploy:

```bash
git clone https://github.com/yourusername/wordpress-vps.git
cd wordpress-vps
chmod +x deploy.sh
./deploy.sh
```

The deployment script will:
1. ✅ Check Docker installation
2. ✅ Prompt for configuration (instance name, domain, email)
3. ✅ Generate secure passwords
4. ✅ Create all necessary directories
5. ✅ Pull Docker images
6. ✅ Start and verify all services

**That's it!** Your WordPress site is ready at `https://your_domain.com`

---

## 📁 Boilerplate Structure

```
wordpress-vps/
├── docker-compose.yml              # Production Docker Compose config
├── docker-compose.dev.yml          # Development Docker Compose config
├── docker-compose.override.yml.example  # Scaling example
├── .env                            # Environment variables (auto-generated)
├── .env.example                    # Basic template
├── .env.dev                        # Development template
├── .env.staging                    # Staging template
├── .env.production                 # Production template
├── deploy.sh                       # One-command deployment script
├── setup.sh                        # Automated setup script
├── manage-instances.sh             # Multi-instance management tool
├── README.md                       # This file
├── DEPLOYMENT_GUIDE.md             # Comprehensive guide
├── wp-content/                     # WordPress plugins & themes
├── certs/                          # SSL certificates
├── vhost.d/                        # NGINX configs
├── html/                           # NGINX web root
├── backups/                        # Backups directory
├── logs/                           # Application logs
└── mysql_data/                     # Database volume (git-ignored)
```

---

## 🌍 Deployment Modes

### Local Development

For local testing with simplified setup:

```bash
docker compose -f docker-compose.dev.yml up -d
# Access at http://localhost:8001
```

Use `.env.dev` - No SSL, direct port access, debug logging enabled

### VPS - Single Instance

Deploy one WordPress site on a VPS:

```bash
./deploy.sh
```

Use `.env` or `.env.production` - Full SSL, NGINX proxy, Let's Encrypt

### VPS - Multiple Instances

Manage multiple WordPress sites on same VPS:

```bash
sudo manage-instances.sh create wordpress_prod_01 blog1.com admin@blog1.com
sudo manage-instances.sh create wordpress_prod_02 blog2.com admin@blog2.com
```

Each instance is isolated with its own database, files, config, and SSL certificate.

---

## 🛠️ Environment Templates

### Development (`.env.dev`)

```bash
cp .env.dev .env
docker compose -f docker-compose.dev.yml up -d
```

**Features:** No SSL, direct port (8001), debug enabled, minimal security

### Staging (`.env.staging`)

```bash
cp .env.staging .env
./deploy.sh
```

**Features:** SSL/HTTPS, NGINX proxy, full logging, pre-production ready

### Production (`.env.production`)

```bash
cp .env.production .env
# Edit with real domain and passwords
./deploy.sh
```

**Features:** SSL/HTTPS, NGINX proxy, no debug, production-hardened

---

## 📋 Configuration

### Environment Variables (`.env`)

All credentials are in `.env` (excluded from git for security):

```bash
# Instance naming
INSTANCE_NAME=wordpress_prod_01

# MySQL
MYSQL_VERSION=8.0
MYSQL_ROOT_PASSWORD=your_secure_password
MYSQL_DATABASE=wordpress_db
MYSQL_USER=wordpress_user
MYSQL_PASSWORD=your_secure_db_password

# WordPress
WP_VERSION=latest
WP_DEBUG=false
WORDPRESS_TABLE_PREFIX=wp_

# Domain and SSL
DOMAIN_NAME=your_domain.com
LETSENCRYPT_EMAIL=your_email@your_domain.com

# PHPMyAdmin
PHPMYADMIN_PORT=8080
```

⚠️ **Security:** Always use strong, unique passwords. Generate with:
```bash
openssl rand -base64 32
```

---

## 🎯 Instance Management

### Single Instance

```bash
# View logs
docker compose logs -f wordpress

# Stop containers
docker compose down

# Restart services
docker compose restart

# Check status
docker compose ps
```

### Multiple Instances

```bash
# List all instances
sudo manage-instances.sh list

# Create new instance
sudo manage-instances.sh create wordpress_prod_02 blog2.com admin@blog2.com

# Start instance
sudo manage-instances.sh start wordpress_prod_01

# Stop instance
sudo manage-instances.sh stop wordpress_prod_01

# View instance info
sudo manage-instances.sh info wordpress_prod_01

# View logs
sudo manage-instances.sh logs wordpress_prod_01

# Backup instance
sudo manage-instances.sh backup wordpress_prod_01

# Restore from backup
sudo manage-instances.sh restore wordpress_prod_01 backups/backup_file.tar.gz
```

---

## 💾 Backup & Recovery

### Automated Backup

```bash
# Single instance
sudo manage-instances.sh backup wordpress_prod_01

# Cron for daily backups (add to crontab -e)
0 2 * * * /usr/local/bin/manage-instances.sh backup wordpress_prod_01
```

### Manual Backup

**Database only:**

```bash
docker compose exec db mysqldump -u wordpress_user -p wordpress_db > backup.sql
```

**Files only:**

```bash
tar -czf wordpress_files.tar.gz wp-content/
```

**Complete:**

```bash
tar -czf wordpress_backup.tar.gz \
  --exclude='mysql_data' \
  --exclude='certs' \
  --exclude='.git' \
  .
```

### Restore from Backup

**Complete restore:**

```bash
docker compose down
rm -rf wp-content mysql_data
tar -xzf backup_file.tar.gz
docker compose up -d
```

**Database restore:**

```bash
docker compose exec -i db mysql -u wordpress_user -p wordpress_db < backup.sql
```

---

## 🔒 SSL/HTTPS

### Automatic Setup (Recommended)

Let's Encrypt is automatically configured:

```bash
DOMAIN_NAME=your_domain.com
LETSENCRYPT_EMAIL=your_email@your_domain.com
```

Certificates are automatically:
- Generated on first deployment
- Renewed before expiration
- Stored in `./certs/`

### Manual Renewal

```bash
docker compose exec letsencrypt /app/force_renew
docker compose restart nginx-proxy
```

---

## 🚀 Services Overview

### MySQL Database
- Latest MySQL image
- Persistent data storage
- Health checks enabled
- Automatic backups support

### WordPress Application
- Latest WordPress image
- Custom wp-content mounting
- Debug logging (configurable)
- Auto-scaling support

### PHPMyAdmin
- Database management UI
- Port: 8080 (configurable)
- Secure credentials from .env

### NGINX Reverse Proxy
- Production-grade proxy
- Automatic virtual host management
- HTTP/HTTPS routing
- Performance optimization

### Let's Encrypt SSL
- Automatic certificate generation
- Auto-renewal before expiration
- Wildcard certificate support

---

## 📊 Monitoring & Logs

### View Logs

```bash
# All services
docker compose logs

# Specific service
docker compose logs wordpress
docker compose logs db
docker compose logs nginx-proxy

# Real-time
docker compose logs -f wordpress

# Last 100 lines
docker compose logs --tail=100 wordpress
```

### Container Health

```bash
# Check all containers
docker compose ps

# Resource usage
docker stats

# Detailed inspection
docker inspect wordpress_app
```

---

## 🔧 Troubleshooting

### WordPress Not Accessible

```bash
# Check container status
docker compose ps

# View WordPress logs
docker compose logs wordpress

# Verify DNS
nslookup your_domain.com

# Check ports
sudo netstat -tulpn | grep LISTEN
```

### Database Connection Issues

```bash
# Test connectivity
docker compose exec wordpress wp db check

# View database logs
docker compose logs db

# Connect to MySQL
docker compose exec db mysql -u wordpress_user -p wordpress_db
```

### SSL Certificate Issues

```bash
# Check certificate
docker compose exec nginx-proxy cat /etc/nginx/certs/your_domain.com.crt

# View Let's Encrypt logs
docker compose logs letsencrypt

# Renew certificate
docker compose exec letsencrypt /app/force_renew
```

### Port Already in Use

```bash
# Find process using port 80
sudo lsof -i :80

# Kill process
sudo kill -9 <PID>

# Or use different port in .env
PHPMYADMIN_PORT=8081
```

---

## 📚 Full Documentation

For comprehensive guides on:
- VPS deployment strategies
- Multi-instance setup
- Performance optimization
- Security hardening
- Disaster recovery

👉 See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

---

## 🔐 Security Best Practices

### Essential

✅ Change all default passwords  
✅ Use strong passwords (16+ characters)  
✅ Enable HTTPS (Let's Encrypt)  
✅ Regular backups  
✅ Configure firewall  
✅ Update system regularly  

### Recommended

🔐 Use WordPress security plugins  
🔐 Enable 2FA for admin  
🔐 Limit database access  
🔐 Monitor access logs  
🔐 Implement WAF  
🔐 Set proper file permissions (644/755)  

### Environment File Security

```bash
# Restrict .env permissions
chmod 600 .env

# Add to .gitignore
echo ".env" >> .gitignore
echo "*.env" >> .gitignore

# Never commit sensitive data
```

---

## 📈 Scaling

### Scale WordPress Containers

```bash
# Run 3 WordPress containers
docker compose up -d --scale wordpress=3
```

### Load Balancing

NGINX automatically load balances across WordPress containers.

### Database Optimization

```bash
# Connect to MySQL
docker compose exec db mysql -u wordpress_user -p

# Run optimization
OPTIMIZE TABLE wp_posts;
OPTIMIZE TABLE wp_postmeta;
OPTIMIZE TABLE wp_comments;
```

---

## 🤝 Support & Resources

- 📖 [Docker Documentation](https://docs.docker.com/)
- 📖 [Docker Compose Docs](https://docs.docker.com/compose/)
- 📖 [WordPress Docker Hub](https://hub.docker.com/_/wordpress)
- 📖 [Let's Encrypt Docs](https://letsencrypt.org/docs/)
- 📖 [NGINX Proxy GitHub](https://github.com/jwilder/nginx-proxy)

---

## 📝 File Descriptions

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Production Docker setup with NGINX, Let's Encrypt |
| `docker-compose.dev.yml` | Development setup with direct port access |
| `deploy.sh` | Interactive deployment script |
| `setup.sh` | Automated setup (legacy) |
| `manage-instances.sh` | Multi-instance management tool |
| `.env.dev` | Development configuration template |
| `.env.staging` | Staging configuration template |
| `.env.production` | Production configuration template |
| `DEPLOYMENT_GUIDE.md` | Comprehensive deployment documentation |

---

## 📄 License

This boilerplate is provided as-is for educational and production use.

---

**Last Updated:** September 13, 2026  
**Version:** 2.0 - Production Boilerplate  
**Status:** Production Ready  
**Maintained By:** Your Organization
