#!/bin/bash

# Example Usage Script - WordPress Docker Instance Manager
# This script demonstrates common workflows

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MANAGER="$SCRIPT_DIR/wp-manager.py"

echo "WordPress Docker Manager - Example Workflows"
echo "=============================================="
echo ""

# Check if Python script exists
if [ ! -f "$MANAGER" ]; then
    echo "Error: wp-manager.py not found"
    exit 1
fi

echo "This script shows common usage patterns."
echo ""
echo "Choose an example:"
echo ""
echo "1) Create a simple WordPress site"
echo "2) Create multiple sites"
echo "3) List and manage instances"
echo "4) Backup and restore"
echo "5) View all available commands"
echo ""

read -p "Select example (1-5): " choice

case $choice in
    1)
        echo ""
        echo "=== Example 1: Create a Simple WordPress Site ==="
        echo ""
        echo "Command:"
        echo "  python3 wp-manager.py create mysite"
        echo ""
        echo "This will:"
        echo "  1. Create directory: instances/mysite/"
        echo "  2. Generate secure MySQL passwords"
        echo "  3. Create .env file with configuration"
        echo "  4. Create docker-compose.yml"
        echo "  5. Create instance README"
        echo ""
        echo "Then start it:"
        echo "  python3 wp-manager.py start mysite"
        echo ""
        echo "Access WordPress:"
        echo "  http://localhost:8000"
        echo ""
        ;;
    
    2)
        echo ""
        echo "=== Example 2: Create Multiple Sites ==="
        echo ""
        echo "Commands:"
        echo "  python3 wp-manager.py create blog"
        echo "  python3 wp-manager.py create shop"
        echo "  python3 wp-manager.py create api"
        echo ""
        echo "This creates 3 completely independent instances:"
        echo ""
        echo "  blog:"
        echo "    WordPress: http://localhost:8000"
        echo "    phpMyAdmin: http://localhost:8001"
        echo ""
        echo "  shop:"
        echo "    WordPress: http://localhost:8010"
        echo "    phpMyAdmin: http://localhost:8011"
        echo ""
        echo "  api:"
        echo "    WordPress: http://localhost:8020"
        echo "    phpMyAdmin: http://localhost:8021"
        echo ""
        echo "Each site:"
        echo "  - Has its own MySQL database"
        echo "  - Runs in separate containers"
        echo "  - Uses isolated Docker network"
        echo "  - Can be started/stopped independently"
        echo ""
        ;;
    
    3)
        echo ""
        echo "=== Example 3: List and Manage Instances ==="
        echo ""
        echo "List all instances:"
        echo "  python3 wp-manager.py list"
        echo ""
        echo "Start instance:"
        echo "  python3 wp-manager.py start mysite"
        echo ""
        echo "Stop instance:"
        echo "  python3 wp-manager.py stop mysite"
        echo ""
        echo "Check status:"
        echo "  docker-compose -f instances/mysite/docker-compose.yml ps"
        echo ""
        echo "View logs:"
        echo "  cd instances/mysite && docker-compose logs -f"
        echo ""
        echo "Access MySQL directly:"
        echo "  cd instances/mysite"
        echo "  docker exec -it wp-db-mysite mysql -u root -p"
        echo ""
        ;;
    
    4)
        echo ""
        echo "=== Example 4: Backup and Restore ==="
        echo ""
        echo "Backup entire instance:"
        echo "  python3 wp-manager.py backup mysite"
        echo ""
        echo "This creates:"
        echo "  instances/mysite/backups/db-backup-20240914-120000.sql"
        echo "  instances/mysite/backups/files-backup-20240914-120000.tar.gz"
        echo ""
        echo "Manual database backup:"
        echo "  cd instances/mysite"
        echo "  docker exec wp-db-mysite mysqldump -u wp_mysite -p\$MYSQL_PASSWORD wordpress_mysite > backup.sql"
        echo ""
        echo "Manual database restore:"
        echo "  docker exec -i wp-db-mysite mysql -u wp_mysite -p\$MYSQL_PASSWORD wordpress_mysite < backup.sql"
        echo ""
        echo "Manual file restore:"
        echo "  tar -xzf files-backup-*.tar.gz"
        echo ""
        ;;
    
    5)
        echo ""
        echo "=== All Available Commands ==="
        echo ""
        python3 wp-manager.py --help
        echo ""
        ;;
    
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "For more information, see:"
echo "  - README.md (comprehensive guide)"
echo "  - QUICKSTART.md (5-minute quickstart)"
echo "  - ADVANCED.md (advanced configuration)"
echo ""
