#!/bin/bash

# WordPress Docker Setup Script
# This script initializes the WordPress Docker environment

set -e

echo "=========================================="
echo "WordPress Docker Setup Script"
echo "=========================================="
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
    echo "✓ .env file created"
    echo "⚠️  Please edit .env with your configuration before starting containers"
    exit 1
fi

# Create required directories
echo ""
echo "Creating required directories..."
mkdir -p wp-content certs vhost.d html
echo "✓ Directories created"

# Check Docker installation
echo ""
echo "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi
echo "✓ Docker found: $(docker --version)"

# Check Docker Compose installation
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi
echo "✓ Docker Compose found: $(docker-compose --version)"

# Verify .env configuration
echo ""
echo "Verifying .env configuration..."
if grep -q "change_this" .env; then
    echo "⚠️  Warning: Found placeholder values in .env"
    echo "Please update the following in .env:"
    grep "change_this" .env
    echo ""
    read -p "Do you want to continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Pull and build images
echo ""
echo "Pulling Docker images (this may take several minutes)..."
docker-compose pull

# Start containers
echo ""
echo "Starting Docker containers..."
docker-compose up -d

# Wait for services to be ready
echo ""
echo "Waiting for services to start..."
sleep 10

# Check container status
echo ""
echo "Container Status:"
docker-compose ps

echo ""
echo "=========================================="
echo "✓ Setup Complete!"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Configure your domain DNS to point to this server"
echo "2. Access WordPress: https://\$(grep DOMAIN_NAME .env | cut -d '=' -f2)"
echo "3. PHPMyAdmin: http://\$(grep DOMAIN_NAME .env | cut -d '=' -f2):8080"
echo ""
echo "View logs:"
echo "  docker-compose logs -f"
echo ""
echo "Stop containers:"
echo "  docker-compose down"
echo ""
