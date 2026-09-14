#!/bin/bash

###############################################################################
# VPS WordPress Docker Deployment Script
# Deploy new WordPress instances to a VPS with automatic configuration
###############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

###############################################################################
# Functions
###############################################################################

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

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_requirements() {
    print_header "Checking Requirements"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        echo "Install Docker: https://docs.docker.com/engine/install/"
        exit 1
    fi
    print_success "Docker found: $(docker --version)"
    
    # Check Docker Compose
    if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed"
        echo "Install Docker Compose: https://docs.docker.com/compose/install/"
        exit 1
    fi
    print_success "Docker Compose found: $(docker compose version | head -1)"
    
    # Check root access for Docker
    if ! docker ps &> /dev/null; then
        print_error "Cannot access Docker. Current user may need sudo privileges."
        echo "Add user to docker group: sudo usermod -aG docker \$USER"
        exit 1
    fi
    print_success "Docker access verified"
}

generate_passwords() {
    local length=${1:-32}
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-$((length-1))
}

validate_domain() {
    local domain=$1
    if [[ $domain =~ ^([a-zA-Z0-9](-?[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

create_env_file() {
    local instance_name=$1
    local domain=$2
    local email=$3
    local env_file="${SCRIPT_DIR}/.env"
    
    print_info "Creating environment file..."
    
    # Generate secure passwords
    local mysql_root_pwd=$(generate_passwords 32)
    local mysql_pwd=$(generate_passwords 32)
    
    cat > "$env_file" << EOF
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
    
    print_success "Environment file created: $env_file"
}

setup_directories() {
    print_info "Creating project directories..."
    
    mkdir -p wp-content
    mkdir -p certs
    mkdir -p vhost.d
    mkdir -p html
    mkdir -p backups
    mkdir -p logs
    
    # Set permissions
    chmod 755 wp-content
    chmod 755 backups
    chmod 755 logs
    
    print_success "Directories created"
}

verify_env_config() {
    local env_file="${SCRIPT_DIR}/.env"
    
    print_info "Verifying configuration..."
    
    if [ ! -f "$env_file" ]; then
        print_error ".env file not found"
        return 1
    fi
    
    # Check for required variables
    local required_vars=("INSTANCE_NAME" "MYSQL_ROOT_PASSWORD" "MYSQL_PASSWORD" "DOMAIN_NAME" "LETSENCRYPT_EMAIL")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "$env_file"; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_error "Missing required variables: ${missing_vars[*]}"
        return 1
    fi
    
    # Warn about placeholders
    if grep -q "your_" "$env_file"; then
        print_warning "Found placeholder values in .env file"
        print_info "Please update domain and email configuration:"
        grep "your_" "$env_file"
        return 1
    fi
    
    print_success "Configuration verified"
    return 0
}

pull_images() {
    print_info "Pulling Docker images (this may take several minutes)..."
    cd "$SCRIPT_DIR"
    docker compose pull 2>&1 | grep -E "^[a-z]|Pulled|Error" || true
    print_success "Images pulled successfully"
}

start_services() {
    print_info "Starting Docker services..."
    cd "$SCRIPT_DIR"
    docker compose up -d
    
    # Wait for services to be healthy
    print_info "Waiting for services to start..."
    sleep 15
    
    print_success "Services started"
}

verify_services() {
    print_header "Verifying Services"
    
    cd "$SCRIPT_DIR"
    docker compose ps
    
    # Check database connectivity
    print_info "Checking database connectivity..."
    if docker compose exec -T db mysqladmin ping -h localhost -u root -p"$(grep MYSQL_ROOT_PASSWORD .env | cut -d '=' -f2)" &> /dev/null; then
        print_success "Database is healthy"
    else
        print_error "Database connection failed"
        return 1
    fi
}

display_summary() {
    local domain=$(grep "^DOMAIN_NAME=" "$SCRIPT_DIR/.env" | cut -d '=' -f2)
    local instance=$(grep "^INSTANCE_NAME=" "$SCRIPT_DIR/.env" | cut -d '=' -f2)
    
    print_header "Deployment Complete!"
    
    echo ""
    echo "Instance: $instance"
    echo "Domain: $domain"
    echo ""
    echo "Access Points:"
    echo "  WordPress: https://$domain"
    echo "  Admin: https://$domain/wp-admin"
    echo "  PHPMyAdmin: http://$domain:8080"
    echo ""
    echo "Important Files:"
    echo "  Environment: $SCRIPT_DIR/.env"
    echo "  Compose: $SCRIPT_DIR/docker-compose.yml"
    echo "  Backups: $SCRIPT_DIR/backups/"
    echo ""
    echo "Useful Commands:"
    echo "  View logs: docker compose logs -f"
    echo "  Stop services: docker compose down"
    echo "  Restart services: docker compose restart"
    echo "  Backup database: docker compose exec db mysqldump -u wordpress_user -p wordpress_db > backup.sql"
    echo ""
    echo "Documentation: $SCRIPT_DIR/README.md"
    echo ""
}

###############################################################################
# Main Script
###############################################################################

main() {
    print_header "WordPress Docker VPS Deployment"
    
    # Check if .env already exists
    if [ -f "$SCRIPT_DIR/.env" ]; then
        print_warning ".env file already exists"
        read -p "Do you want to overwrite it? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing configuration"
        else
            # Backup existing .env
            cp "$SCRIPT_DIR/.env" "$SCRIPT_DIR/.env.backup_$TIMESTAMP"
            print_success "Backed up to .env.backup_$TIMESTAMP"
        fi
    else
        # Interactive setup
        print_header "Configuration Setup"
        
        read -p "Instance name (e.g., wordpress_prod_01): " -i "wordpress_prod_01" -e instance_name
        instance_name=${instance_name:-wordpress_prod_01}
        
        while true; do
            read -p "Domain name (e.g., example.com): " domain
            if validate_domain "$domain"; then
                break
            else
                print_error "Invalid domain format. Use: example.com"
            fi
        done
        
        read -p "Email for SSL certificates: " email
        
        create_env_file "$instance_name" "$domain" "$email"
    fi
    
    check_requirements
    setup_directories
    
    if ! verify_env_config; then
        print_error "Configuration verification failed. Please fix .env file."
        exit 1
    fi
    
    echo ""
    read -p "Continue with deployment? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    pull_images
    start_services
    verify_services
    display_summary
}

# Run main function
main "$@"
