# Quick Start Guide

Get up and running with your first WordPress instance in 5 minutes!

## Step 1: Prerequisites Check

```bash
# Verify Docker is installed
docker --version
# Should output: Docker version X.XX.X, ...

# Verify Docker Compose is installed
docker-compose --version
# Should output: Docker Compose version X.X.X, ...

# If Docker is not installed, visit: https://docs.docker.com/get-docker/
# If Docker Compose is not installed, visit: https://docs.docker.com/compose/install/
```

## Step 2: Navigate to Project

```bash
cd ~/Documents/work/clients/Rych/Wordpress-vps
```

## Step 3: Create Your First Instance

### Option A: Using Python (Recommended)
```bash
python3 wp-manager.py create mysite
```

### Option B: Using Bash Script
```bash
./wp-manager.sh create mysite
```

**What happens:**
- ✅ Directory created: `instances/mysite/`
- ✅ Secure passwords generated automatically
- ✅ Configuration file created: `.env`
- ✅ Docker Compose file created: `docker-compose.yml`
- ✅ Sample README created with instructions

## Step 4: Start the Instance

### Python Version:
```bash
python3 wp-manager.py start mysite
```

### Bash Version:
```bash
./wp-manager.sh start mysite
```

**Output should show:**
```
[SUCCESS] Instance started successfully!
[INFO] WordPress: http://localhost:8000
[INFO] phpMyAdmin: http://localhost:8001
```

## Step 5: Access WordPress

Open your web browser and go to:
- **WordPress**: http://localhost:8000
- **phpMyAdmin**: http://localhost:8001

## Step 6: Complete WordPress Installation

You'll see the WordPress setup wizard:

1. **Select Language** → Click "Continue"
2. **Database Connection**
   - Host: `db_mysite` (pre-filled)
   - Username: `wp_mysite` (check `.env` file)
   - Password: (check `.env` file)
   - Database Name: `wordpress_mysite` (pre-filled)
3. **Click "Run Installation"**
4. **Fill in Site Details**
   - Site Title: Your site name
   - Username: WordPress admin username
   - Password: WordPress admin password
   - Email: Your email address
5. **Click "Install WordPress"**
6. **Login** with your credentials

## Done! 🎉

Your WordPress site is now running independently with:
- ✅ Isolated MySQL database
- ✅ Dedicated WordPress container
- ✅ Database management tool (phpMyAdmin)
- ✅ Automatic restart on failure
- ✅ Persistent data storage

## Useful Commands

### Check Instance Status
```bash
python3 wp-manager.py list
```

### View Logs
```bash
cd instances/mysite
docker-compose logs -f
```

### Stop Instance
```bash
python3 wp-manager.py stop mysite
```

### Create Another Instance
```bash
python3 wp-manager.py create shop
python3 wp-manager.py create blog
python3 wp-manager.py create api
```

Each instance:
- Gets unique ports
- Has separate database
- Runs independently
- Can be managed separately

### Backup Everything
```bash
python3 wp-manager.py backup mysite
```

Creates:
- Database dump: `instances/mysite/backups/db-backup-TIMESTAMP.sql`
- Files archive: `instances/mysite/backups/files-backup-TIMESTAMP.tar.gz`

## Troubleshooting

### Port Already in Use?
```bash
python3 wp-manager.py create mysite --wp-port 9000 --pma-port 9001
```

### WordPress Not Loading?
```bash
cd instances/mysite
docker-compose ps
# Should show all containers running

# Wait a bit longer (first boot takes 1-2 minutes)
sleep 60
curl http://localhost:8000
```

### Can't Connect to Database?
```bash
# Check database container
docker-compose logs db_mysite

# Restart database
docker-compose restart db_mysite
```

### Where are my passwords?
```bash
cat instances/mysite/.env
```

Contains:
- `MYSQL_ROOT_PASSWORD` - Database root password
- `MYSQL_PASSWORD` - Database user password
- `MYSQL_USER` - Database username
- `MYSQL_DATABASE` - Database name

## Next Steps

- [Read Full Documentation](README.md)
- [Learn Advanced Configuration](ADVANCED.md)
- [Setup HTTPS/SSL](HTTPS_SETUP.md)
- [Performance Tuning](PERFORMANCE.md)

## Support

For issues or questions:
1. Check the logs: `docker-compose logs`
2. Read the [README.md](README.md#troubleshooting)
3. Check Docker documentation: https://docs.docker.com/
4. Check WordPress documentation: https://wordpress.org/support/

---

**Congratulations! You now have a production-ready, containerized WordPress setup!** 🚀
