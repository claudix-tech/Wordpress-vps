# WordPress Docker Setup

This repository contains a complete Docker setup for running WordPress with Docker Compose, including MySQL database, PHPMyAdmin, NGINX reverse proxy, and Let's Encrypt SSL certificates.

## Prerequisites

- Docker and Docker Compose installed on your system
- Ubuntu 22.04 or later (recommended)
- A domain name (for SSL certificates)
- Basic knowledge of Docker and WordPress

## Quick Start

### 1. Clone or Setup the Repository

```bash
cd /path/to/wordpress-vps
```

### 2. Configure Environment Variables

Edit the `.env` file with your specific configuration:

```bash
nano .env
```

Key variables to update:
- `MYSQL_ROOT_PASSWORD` - Root password for MySQL
- `MYSQL_DATABASE` - WordPress database name
- `MYSQL_USER` - WordPress database user
- `MYSQL_PASSWORD` - WordPress database password
- `DOMAIN_NAME` - Your domain (e.g., example.com)
- `EMAIL` - Email for Let's Encrypt SSL certificates

**⚠️ Important:** Change all default passwords for production environments.

### 3. Create Required Directories

```bash
mkdir -p wp-content certs vhost.d html
```

### 4. Start Docker Containers

```bash
docker-compose up -d
```

This will:
- Pull Docker images from Docker Hub
- Create and start all services
- Configure the WordPress database
- Set up the NGINX reverse proxy

The process may take a few minutes depending on your internet speed.

### 5. Access WordPress

Once all containers are running:

- **WordPress Admin:** `https://your_domain.com/wp-admin`
- **PHPMyAdmin:** `http://your_domain.com:8080`
- **WordPress Frontend:** `https://your_domain.com`

## Services Overview

### MySQL Database (`db`)
- Latest MySQL image
- Persistent data storage in `mysql_data` volume
- Health checks enabled

### WordPress Application (`wordpress`)
- Latest WordPress image
- Depends on database service
- Custom wp-content volume mounting

### PHPMyAdmin (`phpmyadmin`)
- Database management interface
- Port: `8080`
- Access: `http://your_domain.com:8080`

### NGINX Reverse Proxy (`nginx-proxy`)
- Handles incoming HTTP/HTTPS requests
- Manages virtual hosts automatically
- Ports: `80` (HTTP) and `443` (HTTPS)

### Let's Encrypt SSL Companion (`letsencrypt-nginx-proxy-companion`)
- Automatically issues and renews SSL certificates
- Works with NGINX proxy
- Free HTTPS support

## Configuration

### Environment File (`.env`)

All sensitive credentials are stored in the `.env` file. This file is excluded from git for security.

### Docker Compose File

The `docker-compose.yml` defines all services and their configurations. Key features:
- Service dependencies
- Volume management
- Network configuration
- Environment variables
- Health checks

## Common Operations

### View Container Logs

```bash
# All containers
docker-compose logs

# Specific container
docker-compose logs wordpress
docker-compose logs db
```

### Stop Containers

```bash
docker-compose down
```

### Restart Containers

```bash
docker-compose restart
```

### Scale WordPress Containers

```bash
docker-compose up -d --scale wordpress=3
```

### Database Backup

```bash
docker exec wordpress_db mysqldump -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} > backup.sql
```

### Database Restore

```bash
docker exec -i wordpress_db mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} < backup.sql
```

## Backup and Recovery

### Backup WordPress Files

```bash
cp -r wp-content backup_$(date +%Y%m%d_%H%M%S)
```

### Backup Database

```bash
docker exec wordpress_db mysqldump -u ${MYSQL_USER} -p${MYSQL_PASSWORD} ${MYSQL_DATABASE} > wordpress_backup_$(date +%Y%m%d_%H%M%S).sql
```

### Full System Backup

```bash
tar -czf wordpress_full_backup_$(date +%Y%m%d_%H%M%S).tar.gz \
  --exclude='mysql_data' \
  --exclude='certs' \
  --exclude='.git' \
  .
```

## Troubleshooting

### Containers Not Starting

```bash
# Check container status
docker-compose ps

# View logs for errors
docker-compose logs

# Restart specific service
docker-compose restart wordpress
```

### Database Connection Issues

```bash
# Verify database is healthy
docker-compose logs db

# Check database connectivity
docker exec wordpress_app wp --allow-root db check
```

### Port Already in Use

If ports 80 or 443 are already in use:

1. Find the process using the port:
   ```bash
   sudo lsof -i :80
   sudo lsof -i :443
   ```

2. Either stop the process or modify the ports in `docker-compose.yml`

### SSL Certificate Issues

```bash
# View certificate details
docker exec nginx_proxy cat /etc/nginx/certs/your_domain.com.crt

# Restart Let's Encrypt service
docker-compose restart letsencrypt-nginx-proxy-companion
```

## Security Best Practices

1. **Change Default Credentials:** Always change `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` in `.env`
2. **Use Strong Passwords:** Implement complex passwords (minimum 16 characters)
3. **Keep Images Updated:** Regularly update Docker images
4. **Regular Backups:** Implement automated backup strategy
5. **Monitor Logs:** Check container logs regularly for security issues
6. **Firewall Rules:** Configure firewall to allow only necessary ports (80, 443, 8080)
7. **SSL Enabled:** Always use HTTPS for WordPress admin access
8. **Environment Variables:** Never commit `.env` file to version control

## Directory Structure

```
.
├── .env                          # Environment variables (excluded from git)
├── .gitignore                    # Git ignore file
├── docker-compose.yml            # Docker Compose configuration
├── README.md                     # This file
├── wp-content/                   # WordPress plugins and themes
├── certs/                        # SSL certificates
├── vhost.d/                      # NGINX virtual host configs
├── html/                         # NGINX web root
└── mysql_data/                   # MySQL database volume (excluded from git)
```

## Production Deployment Checklist

- [ ] Update `.env` with production credentials
- [ ] Configure domain DNS to point to server
- [ ] Set up automatic backups
- [ ] Enable WordPress security plugins
- [ ] Configure firewall rules
- [ ] Set up monitoring and alerts
- [ ] Review and update WordPress plugins
- [ ] Enable SSL certificate auto-renewal
- [ ] Configure log rotation
- [ ] Set up email notifications

## Additional Resources

- [Hostinger Docker WordPress Tutorial](https://www.hostinger.com/tutorials/run-docker-wordpress/)
- [Docker Official Documentation](https://docs.docker.com/)
- [WordPress Docker Image](https://hub.docker.com/_/wordpress)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

## Support

For issues or questions:

1. Check the logs: `docker-compose logs`
2. Verify configuration in `.env`
3. Consult Docker and WordPress documentation
4. Review the troubleshooting section above

## License

This setup is provided as-is for educational and deployment purposes.

---

**Last Updated:** 2026-09-13
**Version:** 1.0
