# Advanced Configuration

## Environment Variables Reference

Each instance's `.env` file controls all configuration. Edit and restart to apply changes.

### MySQL Configuration

```env
MYSQL_ROOT_PASSWORD=SecurePassword123!
MYSQL_DATABASE=wordpress_mysite
MYSQL_USER=wp_mysite
MYSQL_PASSWORD=SecureDbPassword456!
```

- **Root Password**: Used for database administration
- **Database Name**: Name of the WordPress database
- **User**: WordPress database user
- **Password**: WordPress database user password

### WordPress Configuration

```env
WP_TABLE_PREFIX=wp_
WP_PORT=8000
PMA_PORT=8001
```

- **Table Prefix**: Prefix for all WordPress tables (security by obscurity)
- **WordPress Port**: Port to access WordPress (external)
- **phpMyAdmin Port**: Port to access phpMyAdmin (external)

### Custom WordPress Configuration

Add to `docker-compose.yml` under `wordpress_{instance}` service:

```yaml
environment:
  WORDPRESS_CONFIG_EXTRA: |
    define('WP_MEMORY_LIMIT', '256M');
    define('WP_MAX_MEMORY_LIMIT', '512M');
    define('AUTOMATIC_UPDATER_DISABLED', false);
    define('WP_AUTO_UPDATE_CORE', true);
```

### Upload & Resource Limits (5GB)

Each instance is pre-configured to support uploads up to **5GB** (ideal for large migrations with All-in-One WP Migration, video files, and backups):

1. **PHP Configuration (`instances/{name}/uploads.ini`)**:
   Mounted to `/usr/local/etc/php/conf.d/uploads.ini`:
   ```ini
   file_uploads = On
   memory_limit = 1024M
   upload_max_filesize = 5120M
   post_max_size = 5120M
   max_execution_time = 3600
   max_input_time = 3600
   max_file_uploads = 50
   ```

2. **Apache Configuration (`instances/{name}/apache-limits.conf`)**:
   Mounted to `/etc/apache2/conf-enabled/limits.conf`:
   ```apache
   LimitRequestBody 0
   Timeout 3600
   ```

3. **Reverse Proxy Configuration (if using NGINX)**:
   If using an NGINX reverse proxy in front of WordPress, ensure `client_max_body_size` is set:
   ```nginx
   client_max_body_size 5G;
   proxy_connect_timeout 3600s;
   proxy_send_timeout 3600s;
   proxy_read_timeout 3600s;
   ```

To modify these values for an instance, edit `instances/{name}/uploads.ini` or `instances/{name}/apache-limits.conf` and reload:
```bash
cd instances/{name}
docker compose restart
```

## Performance Optimization

### Database Optimization

```bash
# Access database container
docker exec -it wp-db-mysite mysql -u root -p

# Run optimization (from MySQL prompt)
OPTIMIZE TABLE wordpress_mysite.wp_posts;
OPTIMIZE TABLE wordpress_mysite.wp_postmeta;
OPTIMIZE TABLE wordpress_mysite.wp_comments;
OPTIMIZE TABLE wordpress_mysite.wp_commentmeta;
OPTIMIZE TABLE wordpress_mysite.wp_terms;
OPTIMIZE TABLE wordpress_mysite.wp_term_taxonomy;
OPTIMIZE TABLE wordpress_mysite.wp_links;
OPTIMIZE TABLE wordpress_mysite.wp_options;

# Exit
exit;
```

### Enable PHP Caching

Add to `docker-compose.yml` WordPress service environment:

```yaml
WORDPRESS_CONFIG_EXTRA: |
  define('WP_MEMORY_LIMIT', '256M');
  define('WP_MAX_MEMORY_LIMIT', '512M');
  define('CONCATENATE_SCRIPTS', false);
  define('COMPRESS_SCRIPTS', true);
  define('COMPRESS_CSS', true);
```

### Install Redis Cache

Add to `docker-compose.yml`:

```yaml
redis:
  image: redis:7-alpine
  container_name: wp-redis-mysite
  restart: always
  networks:
    - wordpress_network_mysite

wordpress_{instance}:
  # ... existing config ...
  depends_on:
    - db_{instance}
    - redis
  environment:
    # ... existing environment ...
    WORDPRESS_CONFIG_EXTRA: |
      define('WP_REDIS_HOST', 'redis');
      define('WP_REDIS_PORT', 6379);
```

Then install Redis plugin in WordPress admin.

### Resource Limits

Add to `docker-compose.yml` services:

```yaml
wordpress_{instance}:
  deploy:
    resources:
      limits:
        cpus: '1.0'
        memory: 512M
      reservations:
        cpus: '0.5'
        memory: 256M

db_{instance}:
  deploy:
    resources:
      limits:
        cpus: '1.0'
        memory: 1G
      reservations:
        cpus: '0.5'
        memory: 512M
```

## HTTPS/SSL Configuration

### Using Let's Encrypt (Recommended)

**Prerequisites:**
- Domain name pointing to your server
- Port 80 and 443 accessible

**Setup:**

1. Add NGINX proxy to main `docker-compose.yml`:

```yaml
version: "3.9"

services:
  nginx-proxy:
    image: jwilder/nginx-proxy:latest
    container_name: nginx-proxy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - ./certs:/etc/nginx/certs
      - ./vhost.d:/etc/nginx/vhost.d
      - ./html:/usr/share/nginx/html
    networks:
      - nginx-proxy-network

  letsencrypt:
    image: jrcs/letsencrypt-nginx-proxy-companion:latest
    container_name: letsencrypt
    restart: always
    environment:
      NGINX_PROXY_CONTAINER: nginx-proxy
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./certs:/etc/nginx/certs
      - ./vhost.d:/etc/nginx/vhost.d
      - ./html:/usr/share/nginx/html

networks:
  nginx-proxy-network:
    driver: bridge
```

2. Update instance's `docker-compose.yml`:

```yaml
wordpress_{instance}:
  # Remove port mapping:
  # ports:
  #   - "${WP_PORT}:80"
  
  # Add labels:
  labels:
    - "com.example.description=WordPress instance"
    - "VIRTUAL_HOST=yourdomain.com,www.yourdomain.com"
    - "LETSENCRYPT_HOST=yourdomain.com,www.yourdomain.com"
    - "LETSENCRYPT_EMAIL=admin@yourdomain.com"
  
  # Update network:
  networks:
    - nginx-proxy-network

networks:
  nginx-proxy-network:
    external: true
```

3. Update WordPress configuration:

```yaml
environment:
  WORDPRESS_CONFIG_EXTRA: |
    define('WP_HOME', 'https://yourdomain.com');
    define('WP_SITEURL', 'https://yourdomain.com');
    if (strpos($_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false) {
      $_SERVER['HTTPS'] = 'on';
    }
```

## Custom Plugins and Themes

### Add Custom Plugin

```bash
mkdir -p instances/mysite/wp-content/plugins/my-plugin

# Copy plugin files
cp -r ~/my-wordpress-plugin/* instances/mysite/wp-content/plugins/my-plugin/

# Activate in WordPress admin
# Dashboard → Plugins → Activate
```

### Add Custom Theme

```bash
mkdir -p instances/mysite/wp-content/themes/my-theme

# Copy theme files
cp -r ~/my-wordpress-theme/* instances/mysite/wp-content/themes/my-theme/

# Switch in WordPress admin
# Dashboard → Appearance → Themes → Activate
```

### Version Control for Plugins/Themes

```bash
cd instances/mysite

# Add plugins to git
git add wp-content/plugins/

# Add themes to git
git add wp-content/themes/

# Exclude uploads
echo "wp-content/uploads/" >> .gitignore

git commit -m "Add custom plugins and themes"
```

## Database Backup & Restore

### Manual Database Export

```bash
cd instances/mysite

# Export all data
docker exec wp-db-mysite mysqldump -u wp_mysite -p$MYSQL_PASSWORD wordpress_mysite > backup.sql

# Export specific table
docker exec wp-db-mysite mysqldump -u wp_mysite -p$MYSQL_PASSWORD wordpress_mysite wp_posts > posts.sql
```

### Manual Database Import

```bash
cd instances/mysite

# Import full backup
docker exec -i wp-db-mysite mysql -u wp_mysite -p$MYSQL_PASSWORD wordpress_mysite < backup.sql

# Import specific table
docker exec -i wp-db-mysite mysql -u wp_mysite -p$MYSQL_PASSWORD wordpress_mysite < posts.sql
```

### Automated Backup Script

Create `backup-all.sh`:

```bash
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
CENTRAL_BACKUP="$SCRIPT_DIR/backups/central"

mkdir -p "$CENTRAL_BACKUP"

for instance_dir in "$SCRIPT_DIR/instances"/*; do
    if [ -d "$instance_dir" ]; then
        instance_name=$(basename "$instance_dir")
        echo "Backing up $instance_name..."
        
        python3 "$SCRIPT_DIR/wp-manager.py" backup "$instance_name"
        
        # Also copy to central backup location
        cp -r "$instance_dir/backups" "$CENTRAL_BACKUP/$instance_name-$BACKUP_DATE"
    fi
done

echo "All backups complete"
```

Run with cron:

```bash
chmod +x backup-all.sh

# Edit crontab
crontab -e

# Add line (daily at 2 AM)
0 2 * * * /path/to/backup-all.sh
```

## Multi-Instance Load Balancing

### With HAProxy

Create `haproxy/Dockerfile`:

```dockerfile
FROM haproxy:2.8-alpine
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
```

Create `haproxy/haproxy.cfg`:

```
global
  log stdout local0
  log stdout local1 notice
  chroot /var/lib/haproxy
  stats socket /run/haproxy/admin.sock mode 660 level admin
  stats timeout 30s
  daemon

defaults
  log     global
  mode    http
  option  httplog
  option  denylogsend
  timeout connect 5000
  timeout client  50000
  timeout server  50000

frontend http-in
  bind *:80
  default_backend wordpress_backends

backend wordpress_backends
  balance roundrobin
  server wp1 wp-app-site1:80 check
  server wp2 wp-app-site2:80 check
  server wp3 wp-app-site3:80 check
```

Add to main `docker-compose.yml`:

```yaml
haproxy:
  build: ./haproxy
  container_name: wordpress-lb
  restart: always
  ports:
    - "80:80"
  depends_on:
    - wordpress_site1
    - wordpress_site2
    - wordpress_site3
  networks:
    - load-balance-network
```

## Monitoring and Logging

### Docker Stats

```bash
# Monitor container resource usage
docker stats

# Or specific instance
docker-compose -f instances/mysite/docker-compose.yml stats
```

### Centralized Logging with ELK Stack

Add to main `docker-compose.yml`:

```yaml
elasticsearch:
  image: docker.elastic.co/elasticsearch/elasticsearch:8.0.0
  environment:
    - discovery.type=single-node
    - xpack.security.enabled=false
  ports:
    - "9200:9200"

kibana:
  image: docker.elastic.co/kibana/kibana:8.0.0
  ports:
    - "5601:5601"
  depends_on:
    - elasticsearch
```

## Security Hardening

### Update WordPress Configuration

Add to `docker-compose.yml` WordPress service:

```yaml
WORDPRESS_CONFIG_EXTRA: |
  define('DISALLOW_FILE_EDIT', true);
  define('DISALLOW_FILE_MODS', true);
  define('AUTOMATIC_UPDATER_DISABLED', false);
  define('WP_AUTO_UPDATE_CORE', 'minor');
  define('WP_DISABLE_FATAL_ERROR_HANDLER', false);
  
  // Security headers
  header('X-Content-Type-Options: nosniff');
  header('X-Frame-Options: SAMEORIGIN');
  header('X-XSS-Protection: 1; mode=block');
```

### Firewall Configuration

For production, restrict access:

```bash
# Allow only necessary ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw default deny incoming
sudo ufw enable
```

### Regular Updates

```bash
# Update Docker images
docker-compose pull

# Rebuild with new images
docker-compose up -d

# Clean up old images
docker image prune
```

## Troubleshooting Advanced Issues

### High Memory Usage

```bash
# Check container stats
docker-compose stats

# Reduce WordPress memory limit
# Edit instances/mysite/.env or docker-compose.yml
WP_MEMORY_LIMIT=128M  # Reduce from 256M

docker-compose restart wordpress_mysite
```

### Slow Database Performance

```bash
# Check database logs
docker-compose logs db_mysite

# Enter database container
docker exec -it wp-db-mysite mysql -u root -p

# Check slow query log (in MySQL)
show variables like 'slow_query_log';
set global slow_query_log=1;
set global long_query_time=2;
```

### Container Won't Start

```bash
# Check container status
docker-compose ps

# View detailed logs
docker-compose logs

# Check system resources
docker stats

# Restart Docker daemon if needed
sudo systemctl restart docker
```

---

For more help, see [README.md](README.md) or the official documentation links provided there.
