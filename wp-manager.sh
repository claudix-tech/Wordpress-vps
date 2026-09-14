#!/bin/bash

################################################################################
# WordPress Docker Instance Manager
# Initializes fresh, independent WordPress instances with Docker
# Each instance has its own:
#  - Database
#  - WordPress container
#  - phpMyAdmin interface
#  - Isolated network
#  - Unique ports
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

################################################################################
# Helper Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

################################################################################
# Generate Random Passwords
################################################################################

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

################################################################################
# Validate Instance Name
################################################################################

validate_instance_name() {
    local name=$1
    if [[ ! $name =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid instance name: '$name'"
        log_info "Use only alphanumeric characters, hyphens, and underscores"
        return 1
    fi
    return 0
}

################################################################################
# Find Available Port
################################################################################

find_available_port() {
    local start_port=$1
    local port=$start_port
    
    while netstat -tuln 2>/dev/null | grep -q ":$port "; do
        port=$((port + 1))
    done
    
    echo $port
}

################################################################################
# Create Instance
################################################################################

create_instance() {
    local instance_name=$1
    local wp_port=$2
    local pma_port=$3
    
    print_header "Creating WordPress Instance: $instance_name"
    
    # Validate instance name
    if ! validate_instance_name "$instance_name"; then
        return 1
    fi
    
    # Create instance directory
    local instance_dir="$SCRIPT_DIR/instances/$instance_name"
    
    if [ -d "$instance_dir" ]; then
        log_error "Instance '$instance_name' already exists at $instance_dir"
        return 1
    fi
    
    log_info "Creating instance directory..."
    mkdir -p "$instance_dir"
    
    # Create subdirectories
    mkdir -p "$instance_dir/wp-content/uploads"
    mkdir -p "$instance_dir/wp-content/plugins"
    mkdir -p "$instance_dir/wp-content/themes"
    mkdir -p "$instance_dir/backups"
    
    # Generate random passwords
    log_info "Generating secure passwords..."
    local mysql_root_password=$(generate_password)
    local mysql_password=$(generate_password)
    
    # Create .env file
    log_info "Creating environment configuration..."
    cat > "$instance_dir/.env" << EOF
# WordPress Instance: $instance_name
# Generated: $(date)
# DO NOT commit this file to git!

# MySQL Configuration
MYSQL_ROOT_PASSWORD=$mysql_root_password
MYSQL_DATABASE=wordpress_${instance_name}
MYSQL_USER=wp_${instance_name}
MYSQL_PASSWORD=$mysql_password

# WordPress Configuration
WP_TABLE_PREFIX=wp_
WP_PORT=$wp_port
PMA_PORT=$pma_port

# Instance Metadata
INSTANCE_NAME=$instance_name
INSTANCE_DOMAIN=localhost:$wp_port
INSTANCE_EMAIL=admin@$instance_name.local
EOF
    
    # Create docker-compose.yml
    log_info "Creating docker-compose configuration..."
    sed "s/{{INSTANCE_NAME}}/$instance_name/g" "$SCRIPT_DIR/docker-compose.yml.template" > "$instance_dir/docker-compose.yml"
    
    # Create .dockerignore
    cat > "$instance_dir/.dockerignore" << EOF
.git
.gitignore
.env.local
backups
*.sql
*.tar.gz
.DS_Store
Thumbs.db
*.log
EOF
    
    # Create README
    cat > "$instance_dir/README.md" << EOF
# WordPress Instance: $instance_name

## Instance Details
- **Created**: $(date)
- **WordPress Port**: $wp_port
- **phpMyAdmin Port**: $pma_port
- **Database**: wordpress_${instance_name}
- **DB User**: wp_${instance_name}

## Container Names
- WordPress: \`wp-app-$instance_name\`
- Database: \`wp-db-$instance_name\`
- phpMyAdmin: \`wp-pma-$instance_name\`

## Getting Started

### Start the instance
\`\`\`bash
cd $instance_name
docker-compose up -d
\`\`\`

### Access WordPress
Open your browser and navigate to:
http://localhost:$wp_port

### Access phpMyAdmin
Open your browser and navigate to:
http://localhost:$pma_port

### Stop the instance
\`\`\`bash
docker-compose down
\`\`\`

### Stop and remove volumes
\`\`\`bash
docker-compose down -v
\`\`\`

## Backup & Restore

### Backup Database
\`\`\`bash
docker exec wp-db-$instance_name mysqldump -u wp_${instance_name} -p\${MYSQL_PASSWORD} wordpress_${instance_name} > backups/db-backup-\$(date +%Y%m%d-%H%M%S).sql
\`\`\`

### Backup WordPress Files
\`\`\`bash
tar -czf backups/wordpress-backup-\$(date +%Y%m%d-%H%M%S).tar.gz wp-content/
\`\`\`

### Restore Database
\`\`\`bash
docker exec -i wp-db-$instance_name mysql -u wp_${instance_name} -p\${MYSQL_PASSWORD} wordpress_${instance_name} < backups/db-backup.sql
\`\`\`

## Logs

### View all logs
\`\`\`bash
docker-compose logs -f
\`\`\`

### View WordPress logs
\`\`\`bash
docker-compose logs -f wordpress_$instance_name
\`\`\`

### View Database logs
\`\`\`bash
docker-compose logs -f db_$instance_name
\`\`\`

## Environment Variables
All configuration is stored in the \`.env\` file. Update this file to change settings, then restart:
\`\`\`bash
docker-compose down
docker-compose up -d
\`\`\`

**⚠️ Important**: Never commit the \`.env\` file to git as it contains sensitive credentials!

## Troubleshooting

### Container won't start
Check logs:
\`\`\`bash
docker-compose logs
\`\`\`

### Database connection error
Ensure the database container is running:
\`\`\`bash
docker-compose ps
\`\`\`

### Port already in use
Modify \`WP_PORT\` and \`PMA_PORT\` in the \`.env\` file and restart.

### Clear everything and start fresh
\`\`\`bash
docker-compose down -v
rm -rf wp-content/*
docker-compose up -d
\`\`\`

EOF
    
    log_success "Instance directory created at: $instance_dir"
    log_info "Environment configuration saved to: $instance_dir/.env"
    log_info "Docker Compose configuration saved to: $instance_dir/docker-compose.yml"
    
    return 0
}

################################################################################
# Start Instance
################################################################################

start_instance() {
    local instance_name=$1
    local instance_dir="$SCRIPT_DIR/instances/$instance_name"
    
    if [ ! -d "$instance_dir" ]; then
        log_error "Instance '$instance_name' not found"
        return 1
    fi
    
    print_header "Starting WordPress Instance: $instance_name"
    
    cd "$instance_dir"
    
    log_info "Starting Docker containers..."
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        # Extract port from .env
        local wp_port=$(grep "^WP_PORT=" .env | cut -d'=' -f2)
        local pma_port=$(grep "^PMA_PORT=" .env | cut -d'=' -f2)
        
        log_success "Instance started successfully!"
        log_info "WordPress URL: http://localhost:$wp_port"
        log_info "phpMyAdmin URL: http://localhost:$pma_port"
        
        # Wait for WordPress to be ready
        log_info "Waiting for WordPress to be ready (this may take a minute)..."
        sleep 10
        
        return 0
    else
        log_error "Failed to start instance"
        return 1
    fi
}

################################################################################
# Stop Instance
################################################################################

stop_instance() {
    local instance_name=$1
    local instance_dir="$SCRIPT_DIR/instances/$instance_name"
    
    if [ ! -d "$instance_dir" ]; then
        log_error "Instance '$instance_name' not found"
        return 1
    fi
    
    print_header "Stopping WordPress Instance: $instance_name"
    
    cd "$instance_dir"
    docker-compose down
    
    log_success "Instance stopped"
    return 0
}

################################################################################
# List Instances
################################################################################

list_instances() {
    print_header "WordPress Instances"
    
    local instances_dir="$SCRIPT_DIR/instances"
    
    if [ ! -d "$instances_dir" ] || [ -z "$(ls -A $instances_dir 2>/dev/null)" ]; then
        log_warn "No instances found"
        return 0
    fi
    
    for instance_dir in "$instances_dir"/*; do
        if [ -d "$instance_dir" ]; then
            local instance_name=$(basename "$instance_dir")
            
            if [ -f "$instance_dir/.env" ]; then
                local wp_port=$(grep "^WP_PORT=" "$instance_dir/.env" | cut -d'=' -f2)
                local pma_port=$(grep "^PMA_PORT=" "$instance_dir/.env" | cut -d'=' -f2)
                
                # Check if running
                if docker ps --format "{{.Labels}}" | grep -q "com.wordpress.instance=$instance_name"; then
                    local status="${GREEN}RUNNING${NC}"
                else
                    local status="${RED}STOPPED${NC}"
                fi
                
                echo -e "  Name: ${BLUE}$instance_name${NC}"
                echo -e "  Status: $status"
                echo -e "  WordPress: http://localhost:$wp_port"
                echo -e "  phpMyAdmin: http://localhost:$pma_port"
                echo ""
            fi
        fi
    done
}

################################################################################
# Delete Instance
################################################################################

delete_instance() {
    local instance_name=$1
    local instance_dir="$SCRIPT_DIR/instances/$instance_name"
    
    if [ ! -d "$instance_dir" ]; then
        log_error "Instance '$instance_name' not found"
        return 1
    fi
    
    print_header "Deleting WordPress Instance: $instance_name"
    
    log_warn "This will:"
    log_warn "  - Stop all containers"
    log_warn "  - Remove volumes and networks"
    log_warn "  - Delete the instance directory"
    echo ""
    
    read -p "Are you sure? Type 'yes' to confirm: " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        log_info "Deletion cancelled"
        return 0
    fi
    
    cd "$instance_dir"
    
    log_info "Stopping containers..."
    docker-compose down -v 2>/dev/null || true
    
    log_info "Removing instance directory..."
    cd "$SCRIPT_DIR"
    rm -rf "$instance_dir"
    
    log_success "Instance deleted"
    return 0
}

################################################################################
# Backup Instance
################################################################################

backup_instance() {
    local instance_name=$1
    local instance_dir="$SCRIPT_DIR/instances/$instance_name"
    
    if [ ! -d "$instance_dir" ]; then
        log_error "Instance '$instance_name' not found"
        return 1
    fi
    
    print_header "Backing Up WordPress Instance: $instance_name"
    
    cd "$instance_dir"
    
    local backup_dir="backups"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    # Get database credentials from .env
    local db_user=$(grep "^MYSQL_USER=" .env | cut -d'=' -f2)
    local db_password=$(grep "^MYSQL_PASSWORD=" .env | cut -d'=' -f2)
    local db_name=$(grep "^MYSQL_DATABASE=" .env | cut -d'=' -f2)
    local db_container="wp-db-$instance_name"
    
    log_info "Backing up database..."
    docker exec $db_container mysqldump -u $db_user -p$db_password $db_name > "$backup_dir/db-backup-$timestamp.sql"
    
    log_info "Backing up WordPress files..."
    tar -czf "$backup_dir/files-backup-$timestamp.tar.gz" wp-content/
    
    log_success "Backup completed"
    log_info "Database backup: $backup_dir/db-backup-$timestamp.sql"
    log_info "Files backup: $backup_dir/files-backup-$timestamp.tar.gz"
    
    return 0
}

################################################################################
# Main Menu
################################################################################

show_menu() {
    echo ""
    echo -e "${BLUE}WordPress Docker Instance Manager${NC}"
    echo ""
    echo "1) Create new instance"
    echo "2) Start instance"
    echo "3) Stop instance"
    echo "4) List instances"
    echo "5) Backup instance"
    echo "6) Delete instance"
    echo "7) Exit"
    echo ""
}

################################################################################
# Main Script
################################################################################

main() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        log_info "Please install Docker first: https://docs.docker.com/install/"
        exit 1
    fi
    
    # Check if docker-compose is installed
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        log_info "Please install Docker Compose first: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # If no arguments provided, show interactive menu
    if [ $# -eq 0 ]; then
        while true; do
            show_menu
            read -p "Select option: " choice
            
            case $choice in
                1)
                    read -p "Enter instance name: " instance_name
                    
                    # Auto-find ports
                    local wp_port=$(find_available_port 8000)
                    local pma_port=$(find_available_port $((wp_port + 1)))
                    
                    log_info "Detected available ports: WordPress=$wp_port, phpMyAdmin=$pma_port"
                    
                    create_instance "$instance_name" "$wp_port" "$pma_port"
                    ;;
                2)
                    read -p "Enter instance name: " instance_name
                    start_instance "$instance_name"
                    ;;
                3)
                    read -p "Enter instance name: " instance_name
                    stop_instance "$instance_name"
                    ;;
                4)
                    list_instances
                    ;;
                5)
                    read -p "Enter instance name: " instance_name
                    backup_instance "$instance_name"
                    ;;
                6)
                    read -p "Enter instance name: " instance_name
                    delete_instance "$instance_name"
                    ;;
                7)
                    log_info "Goodbye!"
                    exit 0
                    ;;
                *)
                    log_error "Invalid option"
                    ;;
            esac
        done
    else
        # Command-line mode
        local command=$1
        
        case $command in
            create)
                if [ $# -lt 2 ]; then
                    log_error "Usage: $0 create <instance_name> [wp_port] [pma_port]"
                    exit 1
                fi
                local instance_name=$2
                local wp_port=${3:-8000}
                local pma_port=${4:-8080}
                create_instance "$instance_name" "$wp_port" "$pma_port"
                ;;
            start)
                if [ $# -lt 2 ]; then
                    log_error "Usage: $0 start <instance_name>"
                    exit 1
                fi
                start_instance "$2"
                ;;
            stop)
                if [ $# -lt 2 ]; then
                    log_error "Usage: $0 stop <instance_name>"
                    exit 1
                fi
                stop_instance "$2"
                ;;
            list)
                list_instances
                ;;
            backup)
                if [ $# -lt 2 ]; then
                    log_error "Usage: $0 backup <instance_name>"
                    exit 1
                fi
                backup_instance "$2"
                ;;
            delete)
                if [ $# -lt 2 ]; then
                    log_error "Usage: $0 delete <instance_name>"
                    exit 1
                fi
                delete_instance "$2"
                ;;
            *)
                log_error "Unknown command: $command"
                echo ""
                log_info "Available commands:"
                echo "  create <name> [wp_port] [pma_port]  - Create new instance"
                echo "  start <name>                        - Start instance"
                echo "  stop <name>                         - Stop instance"
                echo "  list                                - List all instances"
                echo "  backup <name>                       - Backup instance"
                echo "  delete <name>                       - Delete instance"
                exit 1
                ;;
        esac
    fi
}

# Run main script
main "$@"
