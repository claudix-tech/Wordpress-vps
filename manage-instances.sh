#!/bin/bash

###############################################################################
# WordPress Instance Management Script
# Manage multiple WordPress instances on a VPS
###############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTANCES_DIR="/opt/wordpress"
LOG_FILE="/var/log/wordpress-manager.log"

###############################################################################
# Functions
###############################################################################

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

list_instances() {
    print_header "WordPress Instances"
    
    if [ ! -d "$INSTANCES_DIR" ]; then
        print_info "No instances directory found: $INSTANCES_DIR"
        return
    fi
    
    local count=0
    for instance_dir in "$INSTANCES_DIR"/*; do
        if [ -d "$instance_dir" ] && [ -f "$instance_dir/docker-compose.yml" ]; then
            count=$((count + 1))
            local instance_name=$(basename "$instance_dir")
            
            echo ""
            echo "Instance #$count: $instance_name"
            echo "Location: $instance_dir"
            
            # Get domain from .env
            if [ -f "$instance_dir/.env" ]; then
                local domain=$(grep "^DOMAIN_NAME=" "$instance_dir/.env" 2>/dev/null | cut -d '=' -f2 || echo "N/A")
                echo "Domain: $domain"
            fi
            
            # Get container status
            cd "$instance_dir"
            if docker compose ps 2>/dev/null | grep -q "Up"; then
                echo -e "Status: ${GREEN}Running${NC}"
            else
                echo -e "Status: ${RED}Stopped${NC}"
            fi
        fi
    done
    
    if [ $count -eq 0 ]; then
        print_info "No instances found"
    fi
}

create_instance() {
    local instance_name=$1
    local domain=$2
    local email=$3
    
    print_header "Creating Instance: $instance_name"
    
    local instance_dir="$INSTANCES_DIR/$instance_name"
    
    # Check if instance already exists
    if [ -d "$instance_dir" ]; then
        print_error "Instance already exists: $instance_dir"
        return 1
    fi
    
    # Create directory structure
    mkdir -p "$instance_dir"
    cd "$instance_dir"
    
    print_info "Copying boilerplate files..."
    
    # Copy boilerplate files
    cp /opt/wordpress-boilerplate/docker-compose.yml .
    cp /opt/wordpress-boilerplate/docker-compose.dev.yml .
    cp /opt/wordpress-boilerplate/README.md .
    mkdir -p wp-content certs vhost.d html backups logs
    
    # Create .env file
    print_info "Generating secure configuration..."
    local mysql_root_pwd=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-31)
    local mysql_pwd=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-31)
    
    cat > .env << EOF
# Instance Configuration
INSTANCE_NAME=${instance_name}
RESTART_POLICY=always

# MySQL Configuration
MYSQL_VERSION=8.0
MYSQL_ROOT_PASSWORD=${mysql_root_pwd}
MYSQL_DATABASE=wordpress_db
MYSQL_USER=wordpress_user
MYSQL_PASSWORD=${mysql_pwd}

# WordPress Configuration
WP_VERSION=latest
WP_DEBUG=false
WP_DEBUG_LOG=false
WORDPRESS_TABLE_PREFIX=wp_

# Domain Configuration
DOMAIN_NAME=${domain}
LETSENCRYPT_EMAIL=${email}

# PHPMyAdmin Configuration
PHPMYADMIN_VERSION=latest
PHPMYADMIN_PORT=8080
EOF
    
    # Set proper permissions
    chmod 600 .env
    chmod 755 wp-content
    
    print_success "Instance directory created: $instance_dir"
    print_info "Configuration saved to: $instance_dir/.env"
}

start_instance() {
    local instance_name=$1
    local instance_dir="$INSTANCES_DIR/$instance_name"
    
    if [ ! -d "$instance_dir" ]; then
        print_error "Instance not found: $instance_name"
        return 1
    fi
    
    print_info "Starting instance: $instance_name"
    cd "$instance_dir"
    
    docker compose up -d
    sleep 10
    
    print_success "Instance started"
    docker compose ps
}

stop_instance() {
    local instance_name=$1
    local instance_dir="$INSTANCES_DIR/$instance_name"
    
    if [ ! -d "$instance_dir" ]; then
        print_error "Instance not found: $instance_name"
        return 1
    fi
    
    print_info "Stopping instance: $instance_name"
    cd "$instance_dir"
    docker compose down
    
    print_success "Instance stopped"
}

backup_instance() {
    local instance_name=$1
    local instance_dir="$INSTANCES_DIR/$instance_name"
    
    if [ ! -d "$instance_dir" ]; then
        print_error "Instance not found: $instance_name"
        return 1
    fi
    
    print_info "Backing up instance: $instance_name"
    cd "$instance_dir"
    
    local backup_file="backups/${instance_name}_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    # Backup files
    tar -czf "$backup_file" \
        --exclude='mysql_data' \
        --exclude='certs' \
        --exclude='vhost.d' \
        --exclude='.env' \
        --exclude='.git' \
        --exclude='logs' \
        .
    
    print_success "Files backed up: $backup_file"
    
    # Backup database
    local db_backup="backups/${instance_name}_db_$(date +%Y%m%d_%H%M%S).sql"
    local db_user=$(grep "^MYSQL_USER=" .env | cut -d '=' -f2)
    local db_pass=$(grep "^MYSQL_PASSWORD=" .env | cut -d '=' -f2)
    local db_name=$(grep "^MYSQL_DATABASE=" .env | cut -d '=' -f2)
    
    docker compose exec -T db mysqldump -u "$db_user" -p"$db_pass" "$db_name" > "$db_backup" 2>/dev/null
    
    if [ -f "$db_backup" ]; then
        print_success "Database backed up: $db_backup"
    else
        print_error "Database backup failed"
    fi
}

restore_instance() {
    local instance_name=$1
    local backup_file=$2
    
    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi
    
    local instance_dir="$INSTANCES_DIR/$instance_name"
    
    if [ ! -d "$instance_dir" ]; then
        print_error "Instance not found: $instance_name"
        return 1
    fi
    
    print_info "Restoring instance from: $backup_file"
    
    cd "$instance_dir"
    
    # Stop instance
    docker compose down
    
    # Backup current state
    tar -czf "backups/${instance_name}_pre_restore_$(date +%Y%m%d_%H%M%S).tar.gz" wp-content/
    
    # Extract backup
    tar -xzf "$backup_file"
    
    # Start instance
    docker compose up -d
    
    print_success "Instance restored from: $backup_file"
}

view_logs() {
    local instance_name=$1
    local instance_dir="$INSTANCES_DIR/$instance_name"
    
    if [ ! -d "$instance_dir" ]; then
        print_error "Instance not found: $instance_name"
        return 1
    fi
    
    cd "$instance_dir"
    docker compose logs -f
}

show_instance_info() {
    local instance_name=$1
    local instance_dir="$INSTANCES_DIR/$instance_name"
    
    if [ ! -d "$instance_dir" ]; then
        print_error "Instance not found: $instance_name"
        return 1
    fi
    
    print_header "Instance Info: $instance_name"
    
    echo "Location: $instance_dir"
    echo ""
    
    cd "$instance_dir"
    
    if [ -f .env ]; then
        echo "Configuration:"
        grep -E "^(INSTANCE_NAME|DOMAIN_NAME|MYSQL_DATABASE|WP_VERSION)" .env | sed 's/^/  /'
        echo ""
    fi
    
    echo "Container Status:"
    docker compose ps | sed 's/^/  /'
    echo ""
    
    echo "Disk Usage:"
    du -sh wp-content/ mysql_data/ backups/ 2>/dev/null | sed 's/^/  /'
}

###############################################################################
# Usage
###############################################################################

usage() {
    cat << EOF
WordPress Instance Manager

Usage: $0 <command> [arguments]

Commands:
  list                          List all instances
  create <name> <domain> <email>  Create new instance
  start <name>                  Start instance
  stop <name>                   Stop instance
  backup <name>                 Backup instance
  restore <name> <file>         Restore from backup
  logs <name>                   View instance logs
  info <name>                   Show instance info
  help                          Show this help message

Examples:
  $0 list
  $0 create wordpress_prod_01 example.com admin@example.com
  $0 start wordpress_prod_01
  $0 backup wordpress_prod_01
  $0 restore wordpress_prod_01 backups/wordpress_prod_01_backup_20260913_120000.tar.gz
  $0 logs wordpress_prod_01
  $0 info wordpress_prod_01

EOF
    exit 0
}

###############################################################################
# Main
###############################################################################

if [ $# -eq 0 ]; then
    usage
fi

case "${1:-}" in
    list)
        list_instances
        ;;
    create)
        if [ $# -ne 4 ]; then
            print_error "Usage: $0 create <name> <domain> <email>"
            exit 1
        fi
        check_root
        create_instance "$2" "$3" "$4"
        ;;
    start)
        if [ $# -ne 2 ]; then
            print_error "Usage: $0 start <name>"
            exit 1
        fi
        start_instance "$2"
        ;;
    stop)
        if [ $# -ne 2 ]; then
            print_error "Usage: $0 stop <name>"
            exit 1
        fi
        stop_instance "$2"
        ;;
    backup)
        if [ $# -ne 2 ]; then
            print_error "Usage: $0 backup <name>"
            exit 1
        fi
        check_root
        backup_instance "$2"
        ;;
    restore)
        if [ $# -ne 3 ]; then
            print_error "Usage: $0 restore <name> <file>"
            exit 1
        fi
        check_root
        restore_instance "$2" "$3"
        ;;
    logs)
        if [ $# -ne 2 ]; then
            print_error "Usage: $0 logs <name>"
            exit 1
        fi
        view_logs "$2"
        ;;
    info)
        if [ $# -ne 2 ]; then
            print_error "Usage: $0 info <name>"
            exit 1
        fi
        show_instance_info "$2"
        ;;
    help)
        usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
