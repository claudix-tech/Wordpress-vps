# WordPress Docker Multi-Instance Manager

A comprehensive Docker-based WordPress management system that enables you to create, manage, and run multiple independent WordPress instances. Each instance is completely isolated with its own database, containers, network, and ports.

## Features

✅ **Fully Isolated Instances** - Each WordPress installation has its own:
- MySQL database container
- WordPress Apache container  
- phpMyAdmin interface
- Docker network
- Persistent volumes
- Unique ports

✅ **Easy Management**
- Interactive menu-driven interface
- Command-line interface for automation
- Automatic port detection to avoid conflicts
- Secure password generation
- Comprehensive logging

✅ **Production-Ready**
- Environment variable support for sensitive data
- Health checks for containers
- Memory optimization settings
- Docker best practices
- Backup and restore functionality

✅ **Comprehensive Documentation**
- Per-instance README files
- Inline script documentation
- Usage examples
- Troubleshooting guides

## Prerequisites

- Docker (v20.10 or later)
- Docker Compose (v2.0 or later)
- Linux/macOS or Windows with WSL2
- Bash shell
- Basic command-line knowledge

### Installation

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install docker.io docker-compose
sudo usermod -aG docker $USER
```

**macOS (with Homebrew):**
```bash
brew install docker docker-compose
```

**Windows:**
- Install Docker Desktop with WSL2 backend
- https://www.docker.com/products/docker-desktop

## Quick Start

### 1. Clone/Navigate to the Repository
```bash
cd ~/Documents/work/clients/Rych/Wordpress-vps
```

### 2. Create Your First Instance

**Interactive Mode:**
```bash
./wp-manager.sh
# Select option 1 and follow prompts
```

**Command Line Mode:**
```bash
# Syntax: ./wp-manager.sh create <instance_name> [wp_port] [pma_port]
./wp-manager.sh create mysite 8080 8081
```

This will:
- Create instance directory at `instances/mysite/`
- Generate secure MySQL passwords
- Create environment configuration (`.env`)
- Generate `docker-compose.yml` with unique service names
- Create instance README with all details

### 3. Start the Instance
```bash
./wp-manager.sh start mysite
```

Wait for containers to be healthy (usually 30-60 seconds)

### 4. Access WordPress
Open your browser:
- **WordPress**: http://localhost:8080
- **phpMyAdmin**: http://localhost:8081

### 5. Complete WordPress Setup
1. Select language → Continue
2. Fill in database info (pre-populated if using the setup wizard)
3. Add site title, username, password, email
4. Click "Install WordPress"
5. Login with your credentials

## Usage Guide

### Interactive Menu
```bash
./wp-manager.sh
```

Shows numbered menu options:
1. Create new instance
2. Start instance
3. Stop instance
4. List instances
5. Backup instance
6. Delete instance
7. Exit

### Command-Line Interface

**Create Instance:**
```bash
# Auto-detect ports
./wp-manager.sh create shop

# Specify custom ports
./wp-manager.sh create shop 8080 8081
./wp-manager.sh create blog 8090 8091
./wp-manager.sh create api 9000 9001
```

**Start/Stop:**
```bash
./wp-manager.sh start mysite
./wp-manager.sh stop mysite
```

**List All Instances:**
```bash
./wp-manager.sh list
```

Output example:
```
  Name: mysite
  Status: RUNNING
  WordPress: http://localhost:8080
  phpMyAdmin: http://localhost:8081

  Name: shop
  Status: STOPPED
  WordPress: http://localhost:8090
  phpMyAdmin: http://localhost:8091
```

**Backup Instance:**
```bash
./wp-manager.sh backup mysite
```

Creates:
- Database dump: `instances/mysite/backups/db-backup-20240914-120000.sql`
- Files archive: `instances/mysite/backups/files-backup-20240914-120000.tar.gz`

**Delete Instance:**
```bash
./wp-manager.sh delete mysite
```

⚠️ This will:
- Stop all containers
- Remove volumes
- Delete the instance directory
- Requires confirmation

## Instance Directory Structure

```
instances/
└── mysite/
    ├── .env                          # Instance configuration (DO NOT COMMIT)
    ├── docker-compose.yml            # Docker services definition
    ├── uploads.ini                   # PHP upload limits (512M)
    ├── README.md                     # Instance-specific documentation
    ├── .dockerignore                 # Docker build ignore file
    ├── wp-content/
    │   ├── uploads/                  # User uploaded files
    │   ├── plugins/                  # WordPress plugins
    │   └── themes/                   # WordPress themes
    └── backups/
        ├── db-backup-*.sql           # Database backups
        └── files-backup-*.tar.gz     # File archives
```

## Environment Configuration

Each instance has a `.env` file with configuration:

```env
# MySQL Configuration
MYSQL_ROOT_PASSWORD=...              # Root password
MYSQL_DATABASE=wordpress_mysite      # Database name
MYSQL_USER=wp_mysite                 # Database user
MYSQL_PASSWORD=...                   # Database user password

# WordPress Configuration
WP_TABLE_PREFIX=wp_                  # WordPress table prefix
WP_PORT=8080                         # WordPress access port
PMA_PORT=8081                        # phpMyAdmin access port

# Instance Metadata
INSTANCE_NAME=mysite
INSTANCE_DOMAIN=localhost:8080
INSTANCE_EMAIL=admin@mysite.local
```

### ⚠️ Important Security Notes

1. **Never commit `.env` files to git** - They contain passwords
2. **Change default passwords** - Generated automatically, but verify
3. **Use HTTPS in production** - Requires additional SSL configuration
4. **Regular backups** - Use the backup command regularly
5. **Keep images updated** - Update Docker images periodically

## Docker Services per Instance

### MySQL Database Container
- **Name**: `wp-db-{instance_name}`
- **Image**: `mysql:8.0`
- **Port**: Internal only (3306)
- **Volumes**: Persistent database storage
- **Health Check**: Automatically restarts if unhealthy

### WordPress Container
- **Name**: `wp-app-{instance_name}`
- **Image**: `wordpress:latest-php8.2-apache`
- **Port**: Configurable (default 8080)
- **Volumes**: wp-content directory
- **Features**: Apache2, PHP 8.2, WordPress CLI ready

### phpMyAdmin Container
- **Name**: `wp-pma-{instance_name}`
- **Image**: `phpmyadmin/phpmyadmin:latest`
- **Port**: Configurable (default 8081)
- **Access**: Database management UI

### Network
- **Name**: `wordpress_network_{instance_name}`
- **Type**: Bridge network
- **Purpose**: Isolated container-to-container communication

## Backup & Restore

### Manual Database Backup
```bash
cd instances/mysite

# Backup
docker exec wp-db-mysite mysqldump -u wp_mysite -p$MYSQL_PASSWORD wordpress_mysite > backups/manual-backup.sql

# Restore
docker exec -i wp-db-mysite mysql -u wp_mysite -p$MYSQL_PASSWORD wordpress_mysite < backups/manual-backup.sql
```

### Manual Files Backup
```bash
cd instances/mysite

# Backup entire wp-content
tar -czf backups/files-backup.tar.gz wp-content/

# Restore
tar -xzf backups/files-backup.tar.gz
```

### Automated Backup Script

Create `backup-all.sh`:
```bash
#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/instances"

for instance_dir in */; do
    instance_name="${instance_dir%/}"
    echo "Backing up $instance_name..."
    $SCRIPT_DIR/wp-manager.sh backup "$instance_name"
done
```

Run with cron:
```bash
chmod +x backup-all.sh

# Add to crontab (daily at 2 AM)
0 2 * * * /path/to/backup-all.sh
```

## Troubleshooting

### Containers Won't Start

**Check logs:**
```bash
cd instances/mysite
docker-compose logs
```

**Common issues:**
- Port already in use → Change `WP_PORT` or `PMA_PORT` in `.env`
- Insufficient disk space → Free up space
- Docker daemon not running → Start Docker service

### Database Connection Error

```bash
# Verify database container is running
docker-compose ps

# Check database logs
docker-compose logs wp-db-mysite

# Restart database
docker-compose restart db_mysite
```

### WordPress Installation Page Not Loading

```bash
# Wait longer for startup (first boot can take 2-3 minutes)
sleep 120

# Check WordPress container logs
docker-compose logs wp-app-mysite

# Check Apache configuration
docker exec wp-app-mysite apache2ctl status
```

### Port Already in Use

```bash
# Find which process is using the port
lsof -i :8080

# Kill the process
kill -9 <PID>

# Or change the port in .env
nano instances/mysite/.env
# Modify WP_PORT=8080 to WP_PORT=8090
docker-compose down
docker-compose up -d
```

### High Memory Usage

Modify WordPress memory limits in `docker-compose.yml`:
```yaml
WORDPRESS_CONFIG_EXTRA: |
  define('WP_MEMORY_LIMIT', '128M');  # Reduce if needed
  define('WP_MAX_MEMORY_LIMIT', '256M');
```

### Reset Instance to Clean State

```bash
cd instances/mysite
docker-compose down -v        # Stop and remove volumes
rm -rf wp-content/*           # Remove WordPress files
docker-compose up -d          # Start fresh
```

## Advanced Configuration

### Enable HTTPS with Let's Encrypt

See [HTTPS_SETUP.md](HTTPS_SETUP.md) for detailed instructions on adding:
- NGINX reverse proxy
- Automatic SSL certificates
- Domain configuration

### Multi-Instance Database Replication

For high-availability setups, see [REPLICATION.md](REPLICATION.md)

### Performance Tuning

See [PERFORMANCE.md](PERFORMANCE.md) for:
- Redis caching
- Database optimization
- CDN integration
- Memory and CPU allocation

### Increased Upload File Size (5GB)

By default, each instance comes pre-configured with a **5GB** upload file size limit (ideal for large migrations with All-in-One WP Migration, video files, and backups):
- `upload_max_filesize = 5120M` (5GB)
- `post_max_size = 5120M` (5GB)
- `memory_limit = 1024M` (1GB)
- `max_execution_time = 3600` (1 hour)
- `max_input_time = 3600` (1 hour)
- Apache `LimitRequestBody 0` (unlimited payload)
- phpMyAdmin `UPLOAD_LIMIT = 5120M`

To adjust these limits for an instance, edit `instances/{name}/uploads.ini` or `instances/{name}/apache-limits.conf` and restart:
```bash
cd instances/{name}
docker compose restart
```

### Custom WordPress Plugins

Plugins are mounted from `instances/{name}/wp-content/plugins/`

```bash
# Add plugin directory
mkdir -p instances/mysite/wp-content/plugins/my-plugin

# Copy plugin files
cp -r ~/my-wordpress-plugin/* instances/mysite/wp-content/plugins/my-plugin/

# Enable in WordPress admin panel
```

### Custom WordPress Themes

```bash
# Add theme directory
mkdir -p instances/mysite/wp-content/themes/my-theme

# Copy theme files
cp -r ~/my-wordpress-theme/* instances/mysite/wp-content/themes/my-theme/

# Select in WordPress Settings → Appearance → Themes
```

## Git Workflow

### Initialize Repository
```bash
cd instances/mysite
git init
git add .

# But NEVER commit these:
echo ".env" >> .gitignore
echo "wp-content/uploads/" >> .gitignore
echo "backups/" >> .gitignore
echo "*.sql" >> .gitignore

git commit -m "Initial WordPress setup"
```

### Version Control Best Practices

Track these:
- ✅ `docker-compose.yml` - Container configuration
- ✅ `wp-content/plugins/` - Custom plugins
- ✅ `wp-content/themes/` - Custom themes
- ✅ `.env.template` - Template only, not actual `.env`

Don't track:
- ❌ `.env` - Contains passwords
- ❌ `wp-content/uploads/` - User uploads
- ❌ Database dumps
- ❌ Full WordPress core (regenerate from image)

## Scaling to Production

### Domain Configuration

```bash
# Update .env
INSTANCE_DOMAIN=mysite.example.com
INSTANCE_EMAIL=admin@mysite.example.com

# Update docker-compose.yml labels for SSL
labels:
  - "VIRTUAL_HOST=mysite.example.com"
  - "LETSENCRYPT_HOST=mysite.example.com"
  - "LETSENCRYPT_EMAIL=admin@mysite.example.com"
```

### Database Optimization

```bash
# SSH into database container
docker exec -it wp-db-mysite mysql -u root -p

# Optimize tables
OPTIMIZE TABLE wordpress_mysite.wp_posts;
OPTIMIZE TABLE wordpress_mysite.wp_postmeta;
OPTIMIZE TABLE wordpress_mysite.wp_comments;
```

### Resource Limits

Update `docker-compose.yml`:
```yaml
wordpress_mysite:
  deploy:
    resources:
      limits:
        cpus: '1.0'
        memory: 512M
      reservations:
        cpus: '0.5'
        memory: 256M
```

## Monitoring

### Container Status
```bash
# Overall status
./wp-manager.sh list

# Detailed status
docker-compose ps
docker-compose stats
```

### Logs
```bash
# All logs
docker-compose logs -f

# Last 100 lines, follow updates
docker-compose logs -f --tail=100

# Just WordPress
docker-compose logs -f wp-app-mysite

# Just database
docker-compose logs -f db_mysite
```

### Health Check
```bash
# Manual health check
docker exec wp-db-mysite mysqladmin ping -h localhost
curl http://localhost:8080/wp-admin/
```

## Support & Documentation

- [Hostinger Tutorial](https://www.hostinger.com/tutorials/run-docker-wordpress/)
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [WordPress Documentation](https://wordpress.org/support/)
- [MySQL Documentation](https://dev.mysql.com/doc/)

## License

This project follows the same license as WordPress (GPLv2 or later).

## Contributing

To improve this tool:
1. Test thoroughly with multiple instances
2. Document any new features
3. Update this README
4. Share improvements with the team

## Changelog

### v1.0 (Initial Release)
- ✅ Create independent WordPress instances
- ✅ Interactive and CLI management
- ✅ Automatic port detection
- ✅ Backup/restore functionality
- ✅ Environment-based configuration
- ✅ Per-instance documentation

---

**Last Updated**: September 14, 2024
**Maintained by**: Your Team
**Questions?** Contact your DevOps team or check the troubleshooting section
