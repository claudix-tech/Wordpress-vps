# WordPress Docker VPS Boilerplate - Deployment Guide

## Overview

This is a production-ready boilerplate for deploying multiple WordPress instances on a VPS using Docker. It includes:

- 🐳 Docker Compose configuration for production
- 🔒 SSL/HTTPS support with Let's Encrypt
- 🛡️ NGINX reverse proxy
- 📊 PHPMyAdmin for database management
- 🔄 Automated backups and restore
- 📈 Multi-instance management
- 🚀 Easy scaling

---

## Prerequisites

### VPS Requirements

- **OS:** Ubuntu 22.04 LTS or later
- **Resources:** Minimum 2GB RAM, 20GB disk (more for multiple instances)
- **Network:** Root SSH access, ports 80/443 available
- **Domain:** Domain name(s) pointing to VPS IP

### Required Software

- Docker Engine 20.10+
- Docker Compose 2.0+
- Git (optional, for version control)
- curl/wget (for remote downloads)

---

## Quick Start - Single Instance

### 1. SSH into Your VPS

```bash
ssh root@your_vps_ip
```

### 2. Clone/Download the Boilerplate

```bash
# Option A: Clone from git
git clone https://github.com/yourusername/wordpress-vps.git
cd wordpress-vps

# Option B: Download as archive
wget https://github.com/yourusername/wordpress-vps/archive/main.zip
unzip main.zip
cd wordpress-vps-main
```

### 3. Run Deployment Script

```bash
chmod +x deploy.sh
./deploy.sh
```

The script will:
- Check Docker installation
- Prompt for configuration (instance name, domain, email)
- Generate secure passwords
- Create directories
- Pull Docker images
- Start all services
- Verify services are healthy

### 4. Access WordPress

After deployment:

```bash
# Get the configured domain
grep "DOMAIN_NAME=" .env | cut -d '=' -f2
```

Access:
- **WordPress:** https://your_domain.com
- **Admin:** https://your_domain.com/wp-admin
- **PHPMyAdmin:** http://your_domain.com:8080

---

## Advanced Setup - Multiple Instances

### 1. Create Instances Directory

```bash
sudo mkdir -p /opt/wordpress
sudo chown $USER:$USER /opt/wordpress
```

### 2. Copy Boilerplate to System

```bash
cp -r . /opt/wordpress-boilerplate
chmod +x /opt/wordpress-boilerplate/manage-instances.sh
sudo cp /opt/wordpress-boilerplate/manage-instances.sh /usr/local/bin/
```

### 3. Create New Instances

```bash
sudo manage-instances.sh create wordpress_prod_01 blog1.com admin@blog1.com
sudo manage-instances.sh create wordpress_prod_02 blog2.com admin@blog2.com
sudo manage-instances.sh create wordpress_prod_03 blog3.com admin@blog3.com
```

### 4. Manage Instances

```bash
# List all instances
sudo manage-instances.sh list

# Start an instance
sudo manage-instances.sh start wordpress_prod_01

# Stop an instance
sudo manage-instances.sh stop wordpress_prod_01

# View instance info
sudo manage-instances.sh info wordpress_prod_01

# View logs
sudo manage-instances.sh logs wordpress_prod_01
```

---

## Configuration

### Environment Variables (.env)

Edit `.env` to customize your deployment:

```bash
# Instance naming
INSTANCE_NAME=wordpress_prod_01

# MySQL settings
MYSQL_VERSION=8.0
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_DATABASE=wordpress_db
MYSQL_USER=wordpress_user
MYSQL_PASSWORD=your_secure_db_password

# WordPress settings
WP_VERSION=latest
WP_DEBUG=false
WORDPRESS_TABLE_PREFIX=wp_

# Domain and SSL
DOMAIN_NAME=your_domain.com
LETSENCRYPT_EMAIL=your_email@your_domain.com

# PHPMyAdmin
PHPMYADMIN_PORT=8080
```

**⚠️ Security:** Always use strong, unique passwords. Generate with:

```bash
openssl rand -base64 32
```

### Docker Compose Configuration

The `docker-compose.yml` includes:

**Services:**
- **db** - MySQL 8.0 database
- **wordpress** - WordPress with Apache
- **phpmyadmin** - Database management UI
- **nginx-proxy** - NGINX reverse proxy
- **letsencrypt** - SSL certificate automation

**Volumes:**
- `mysql_data` - Database persistence
- `wp-content` - Plugins and themes
- `certs` - SSL certificates
- `backups` - Database backups

---

## Backup and Restore

### Automatic Backups

Set up cron for automatic backups:

```bash
# Edit crontab
crontab -e

# Add daily backup (runs at 2 AM)
0 2 * * * cd /path/to/wordpress && docker compose exec -T db mysqldump -u wordpress_user -pYOUR_PASSWORD wordpress_db > backups/backup_$(date +\%Y\%m\%d).sql
```

### Manual Backup

**Full instance backup:**

```bash
cd /path/to/instance
sudo manage-instances.sh backup wordpress_prod_01
```

**Database backup only:**

```bash
cd /path/to/instance
docker compose exec db mysqldump -u wordpress_user -p wordpress_db > backup.sql
```

**Files backup only:**

```bash
tar -czf wordpress_backup_$(date +%Y%m%d).tar.gz wp-content/
```

### Restore from Backup

**Full restore:**

```bash
sudo manage-instances.sh restore wordpress_prod_01 backups/wordpress_prod_01_backup_20260913_120000.tar.gz
```

**Database restore only:**

```bash
cd /path/to/instance
docker compose exec -i db mysql -u wordpress_user -p < backup.sql
```

---

## SSL/HTTPS Setup

### Automatic (Recommended)

Let's Encrypt SSL is automatically configured via environment variables:

```bash
DOMAIN_NAME=your_domain.com
LETSENCRYPT_EMAIL=your_email@your_domain.com
```

Certificates are automatically:
- Generated on first deployment
- Renewed before expiration
- Stored in `./certs/`

### Manual SSL Certificate

If needed, renew manually:

```bash
docker compose exec letsencrypt /app/force_renew
docker compose restart nginx-proxy
```

### Wildcard Certificates

For subdomains, modify `.env`:

```bash
DOMAIN_NAME=*.your_domain.com
LETSENCRYPT_EMAIL=your_email@your_domain.com
```

---

## Performance Optimization

### Scale WordPress Containers

For high traffic, run multiple WordPress instances:

```bash
# Create docker-compose.override.yml
docker compose up -d --scale wordpress=3
```

### Database Optimization

```bash
# Connect to MySQL
docker compose exec db mysql -u wordpress_user -p wordpress_db

# Run optimization
OPTIMIZE TABLE wp_posts;
OPTIMIZE TABLE wp_postmeta;
OPTIMIZE TABLE wp_comments;
```

### Redis Caching

Add Redis to `docker-compose.yml`:

```yaml
  redis:
    image: redis:7-alpine
    container_name: ${INSTANCE_NAME}_redis
    restart: always
    networks:
      - wordpress_network
```

---

## Monitoring and Logging

### View Logs

```bash
# All services
docker compose logs

# Specific service
docker compose logs wordpress
docker compose logs db
docker compose logs nginx-proxy

# Real-time logs
docker compose logs -f wordpress

# Last 100 lines
docker compose logs --tail=100 wordpress
```

### Container Health

```bash
# Check all containers
docker compose ps

# Get container resource usage
docker stats

# Inspect container details
docker inspect wordpress_app
```

### Log Files

Logs are saved in JSON format with rotation:

```bash
/var/lib/docker/containers/<container_id>/
```

---

## Troubleshooting

### WordPress Not Accessible

**Check container status:**

```bash
docker compose ps
docker compose logs wordpress
```

**Verify DNS:**

```bash
nslookup your_domain.com
# Should return your VPS IP
```

**Check ports:**

```bash
sudo netstat -tulpn | grep LISTEN
# Should show ports 80 and 443 listening
```

### Database Connection Issues

```bash
# Test database connectivity
docker compose exec wordpress wp db check

# View database logs
docker compose logs db

# Connect directly to MySQL
docker compose exec db mysql -u wordpress_user -p wordpress_db
```

### SSL Certificate Issues

```bash
# Check certificate status
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

## Maintenance

### Regular Tasks

**Weekly:**
- Check disk space
- Review error logs
- Update WordPress plugins/themes

**Monthly:**
- Test backup restoration
- Update Docker images
- Review security settings

**Quarterly:**
- Full system backup
- Security audit
- Performance optimization

### Update Docker Images

```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d

# Check logs for issues
docker compose logs -f
```

### Database Maintenance

```bash
# Backup before maintenance
docker compose exec db mysqldump -u wordpress_user -p wordpress_db > backup.sql

# Run repair
docker compose exec db mysqlcheck -u wordpress_user -p wordpress_db --repair

# Run optimization
docker compose exec db mysqlcheck -u wordpress_user -p wordpress_db --optimize
```

---

## Security Best Practices

### Essential

- ✅ Change all default passwords
- ✅ Use strong passwords (16+ characters)
- ✅ Enable HTTPS (Let's Encrypt)
- ✅ Set database backups
- ✅ Configure firewall rules
- ✅ Regular security updates

### Recommended

- 🔐 Use WordPress security plugins
- 🔐 Enable 2FA for admin
- 🔐 Limit database access
- 🔐 Use WAF (ModSecurity)
- 🔐 Monitor access logs
- 🔐 Set file permissions (644/755)

### Environment File Security

```bash
# Restrict .env permissions
chmod 600 .env

# Don't commit to git
echo ".env" >> .gitignore

# Use secret management for production
# Consider: HashiCorp Vault, AWS Secrets Manager, etc.
```

---

## Scaling Strategies

### Single VPS - Multiple Domains

```bash
# Deploy multiple instances in same VPS
/opt/wordpress/
├── wordpress_prod_01/  (blog1.com)
├── wordpress_prod_02/  (blog2.com)
├── wordpress_prod_03/  (blog3.com)
```

Each instance has its own:
- Database
- WordPress files
- Backup location
- Configuration

### Load Balancing

For high traffic, add load balancer:

```bash
# HAProxy can distribute traffic across instances
docker run -d --name haproxy \
  -p 80:80 -p 443:443 \
  -v ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg \
  haproxy:latest
```

### Database Replication

For multiple instances sharing data:

```bash
# Configure MySQL replication in docker-compose.yml
# Add master/slave database setup
```

---

## Disaster Recovery

### Complete System Restore

1. **Restore VPS from snapshot**
2. **Install Docker and Docker Compose**
3. **Clone repository**
4. **Restore database backup**
5. **Restore wp-content files**
6. **Restart services**

```bash
# Quick restore script
#!/bin/bash
docker compose down
rm -rf wp-content mysql_data
docker compose exec -i db mysql wordpress_db < backup.sql
tar -xzf wp-content_backup.tar.gz
docker compose up -d
```

### Database Recovery

```bash
# If database is corrupted
docker compose exec db mysql_check -u wordpress_user -p --repair wordpress_db
docker compose exec db mysql_upgrade -u wordpress_user -p wordpress_db
docker compose restart db
```

---

## Support and Resources

- 📖 [Docker Documentation](https://docs.docker.com/)
- 📖 [Docker Compose Docs](https://docs.docker.com/compose/)
- 📖 [WordPress Docker Hub](https://hub.docker.com/_/wordpress)
- 📖 [Let's Encrypt Docs](https://letsencrypt.org/docs/)
- 📖 [NGINX Proxy GitHub](https://github.com/jwilder/nginx-proxy)

---

## License

This boilerplate is provided as-is for educational and production use.

---

**Last Updated:** September 13, 2026
**Version:** 2.0
