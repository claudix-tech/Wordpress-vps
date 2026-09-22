#!/usr/bin/env python3

"""
WordPress Docker Instance Manager (Python Version)
Manage multiple independent WordPress instances using Docker
"""

import os
import sys
import subprocess
import json
import argparse
import shutil
import secrets
import string
import socket
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple

# Global Docker Compose command (set by main())
COMPOSE_CMD: Optional[str] = None

# Supported PHP versions for the WordPress image (wordpress:php{VERSION}-apache)
SUPPORTED_PHP_VERSIONS = ['8.2', '8.3']
DEFAULT_PHP_VERSION = SUPPORTED_PHP_VERSIONS[0]

# Colors for terminal output
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def log_info(msg: str):
    """Log info message"""
    print(f"{Colors.BLUE}[INFO]{Colors.ENDC} {msg}")

def log_success(msg: str):
    """Log success message"""
    print(f"{Colors.GREEN}[SUCCESS]{Colors.ENDC} {msg}")

def log_warn(msg: str):
    """Log warning message"""
    print(f"{Colors.YELLOW}[WARNING]{Colors.ENDC} {msg}")

def log_error(msg: str):
    """Log error message"""
    print(f"{Colors.RED}[ERROR]{Colors.ENDC} {msg}")

def print_header(title: str):
    """Print formatted header"""
    print(f"\n{Colors.BLUE}{'='*50}{Colors.ENDC}")
    print(f"{Colors.BLUE}{title:^50}{Colors.ENDC}")
    print(f"{Colors.BLUE}{'='*50}{Colors.ENDC}\n")

def get_compose_cmd() -> Optional[str]:
    """Detect which Docker Compose command is available (new or old format)"""
    # Try new format first (docker compose)
    try:
        result = subprocess.run(
            ['docker', 'compose', 'version'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            return 'docker compose'
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    
    # Try old format (docker-compose)
    if shutil.which('docker-compose'):
        return 'docker-compose'
    
    return None

def check_dependencies():
    """Check if Docker and Docker Compose are installed"""
    if not shutil.which('docker'):
        log_error("Docker is not installed")
        log_info("Install from: https://docs.docker.com/install/")
        sys.exit(1)
    
    compose_cmd = get_compose_cmd()
    if not compose_cmd:
        log_error("Docker Compose is not installed or not recognized")
        log_info("Install Docker Desktop (includes 'docker compose') or Docker Compose standalone")
        log_info("See: https://docs.docker.com/compose/install/")
        sys.exit(1)
    
    log_info(f"Using Docker Compose: {compose_cmd}")
    return compose_cmd

def generate_password(length: int = 25) -> str:
    """Generate a secure random password"""
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
    password = ''.join(secrets.choice(alphabet) for _ in range(length))
    return password

def validate_instance_name(name: str) -> bool:
    """Validate instance name (alphanumeric, hyphens, underscores only)"""
    if not name:
        return False
    return all(c.isalnum() or c in '-_' for c in name)

def find_available_port(start_port: int = 8000) -> int:
    """Find an available port starting from start_port"""
    port = start_port
    while True:
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('', port))
                return port
        except OSError:
            port += 1

def is_port_in_use(port: int) -> bool:
    """Check if a port is currently in use"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(('', port))
            return False
    except OSError:
        return True

def create_instance(instance_name: str, wp_port: Optional[int] = None, pma_port: Optional[int] = None, php_version: Optional[str] = None) -> bool:
    """Create a new WordPress instance"""
    
    print_header(f"Creating WordPress Instance: {instance_name}")
    
    # Validate instance name
    if not validate_instance_name(instance_name):
        log_error(f"Invalid instance name: '{instance_name}'")
        log_info("Use only alphanumeric characters, hyphens, and underscores")
        return False
    
    script_dir = Path(__file__).parent.resolve()
    instances_dir = script_dir / 'instances'
    instance_dir = instances_dir / instance_name
    
    # Check if instance already exists
    if instance_dir.exists():
        log_error(f"Instance '{instance_name}' already exists")
        return False
    
    # Prompt for ports if not provided
    if wp_port is None:
        default_wp = find_available_port(8000)
        if sys.stdin.isatty():
            try:
                val = input(f"Enter WordPress port [default: {default_wp}]: ").strip()
                wp_port = int(val) if val else default_wp
            except ValueError:
                log_warn(f"Invalid input, using default port: {default_wp}")
                wp_port = default_wp
        else:
            wp_port = default_wp

    if pma_port is None:
        default_pma = find_available_port(wp_port + 1)
        if sys.stdin.isatty():
            try:
                val = input(f"Enter phpMyAdmin port [default: {default_pma}]: ").strip()
                pma_port = int(val) if val else default_pma
            except ValueError:
                log_warn(f"Invalid input, using default port: {default_pma}")
                pma_port = default_pma
        else:
            pma_port = default_pma

    # Check if ports are already in use
    if is_port_in_use(wp_port):
        log_warn(f"Port {wp_port} is already in use by another service!")
        if sys.stdin.isatty():
            confirm = input(f"Continue with port {wp_port} anyway? (y/N): ").strip()
            if confirm.lower() != 'y':
                log_info("Creation cancelled")
                return False

    if is_port_in_use(pma_port):
        log_warn(f"Port {pma_port} is already in use by another service!")
        if sys.stdin.isatty():
            confirm = input(f"Continue with port {pma_port} anyway? (y/N): ").strip()
            if confirm.lower() != 'y':
                log_info("Creation cancelled")
                return False

    log_info(f"Using ports: WordPress={wp_port}, phpMyAdmin={pma_port}")

    # Prompt for PHP version if not provided
    if php_version is None:
        if sys.stdin.isatty():
            print("\nAvailable PHP versions:")
            for idx, v in enumerate(SUPPORTED_PHP_VERSIONS, start=1):
                print(f"  {idx}) PHP {v}")
            val = input(f"Select PHP version [default: PHP {DEFAULT_PHP_VERSION}]: ").strip()
            if not val:
                php_version = DEFAULT_PHP_VERSION
            elif val in SUPPORTED_PHP_VERSIONS:
                php_version = val
            else:
                try:
                    php_version = SUPPORTED_PHP_VERSIONS[int(val) - 1]
                except (ValueError, IndexError):
                    log_warn(f"Invalid selection, using default: PHP {DEFAULT_PHP_VERSION}")
                    php_version = DEFAULT_PHP_VERSION
        else:
            php_version = DEFAULT_PHP_VERSION
    elif php_version not in SUPPORTED_PHP_VERSIONS:
        log_error(f"Unsupported PHP version: '{php_version}' (supported: {', '.join(SUPPORTED_PHP_VERSIONS)})")
        return False

    log_info(f"Using PHP version: {php_version}")

    # Create directories
    log_info("Creating instance directory structure...")
    instance_dir.mkdir(parents=True, exist_ok=True)
    (instance_dir / 'wp-content' / 'uploads').mkdir(parents=True, exist_ok=True)
    (instance_dir / 'wp-content' / 'plugins').mkdir(parents=True, exist_ok=True)
    (instance_dir / 'wp-content' / 'themes').mkdir(parents=True, exist_ok=True)
    (instance_dir / 'backups').mkdir(parents=True, exist_ok=True)
    
    # Generate passwords
    log_info("Generating secure passwords...")
    mysql_root_password = generate_password()
    mysql_password = generate_password()
    
    # Create .env file
    log_info("Creating environment configuration...")
    env_content = f"""# WordPress Instance: {instance_name}
# Generated: {datetime.now().isoformat()}
# DO NOT commit this file to git!

# MySQL Configuration
MYSQL_ROOT_PASSWORD={mysql_root_password}
MYSQL_DATABASE=wordpress_{instance_name}
MYSQL_USER=wp_{instance_name}
MYSQL_PASSWORD={mysql_password}

# WordPress Configuration
WP_TABLE_PREFIX=wp_
WP_PORT={wp_port}
PMA_PORT={pma_port}
PHP_VERSION={php_version}

# Instance Metadata
INSTANCE_NAME={instance_name}
INSTANCE_DOMAIN=localhost:{wp_port}
INSTANCE_EMAIL=admin@{instance_name}.local
"""
    
    env_file = instance_dir / '.env'
    env_file.write_text(env_content)
    env_file.chmod(0o600)  # Restrict permissions
    
    # Create docker-compose.yml
    log_info("Creating docker-compose configuration...")
    template_file = script_dir / 'docker-compose.yml.template'
    if not template_file.exists():
        log_error(f"Template file not found: {template_file}")
        return False
    
    template_content = template_file.read_text()
    compose_content = template_content.replace('{{INSTANCE_NAME}}', instance_name).replace('{{PHP_VERSION}}', php_version)
    
    compose_file = instance_dir / 'docker-compose.yml'
    compose_file.write_text(compose_content)
    
    # Create uploads.ini for PHP upload size limit
    log_info("Creating PHP upload configuration (uploads.ini)...")
    uploads_template_file = script_dir / 'uploads.ini.template'
    if uploads_template_file.exists():
        uploads_ini_content = uploads_template_file.read_text()
    else:
        uploads_ini_content = """; PHP Upload & Resource Limits (5GB)
file_uploads = On
memory_limit = 1024M
upload_max_filesize = 5120M
post_max_size = 5120M
max_execution_time = 3600
max_input_time = 3600
max_file_uploads = 50
"""
    (instance_dir / 'uploads.ini').write_text(uploads_ini_content)

    # Create apache-limits.conf for Apache 5GB upload limit
    log_info("Creating Apache upload configuration (apache-limits.conf)...")
    apache_template_file = script_dir / 'apache-limits.conf.template'
    if apache_template_file.exists():
        apache_conf_content = apache_template_file.read_text()
    else:
        apache_conf_content = """# Apache limits for large file uploads (up to 5GB)
LimitRequestBody 0
Timeout 3600
"""
    (instance_dir / 'apache-limits.conf').write_text(apache_conf_content)
    
    # Create .dockerignore
    dockerignore_content = """
.git
.gitignore
.env.local
backups
*.sql
*.tar.gz
.DS_Store
Thumbs.db
*.log
"""
    (instance_dir / '.dockerignore').write_text(dockerignore_content)
    
    # Create README
    readme_content = f"""# WordPress Instance: {instance_name}

## Instance Details
- **Created**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
- **WordPress Port**: {wp_port}
- **phpMyAdmin Port**: {pma_port}
- **PHP Version**: {php_version}
- **Database**: wordpress_{instance_name}
- **DB User**: wp_{instance_name}

## Container Names
- WordPress: `wp-app-{instance_name}`
- Database: `wp-db-{instance_name}`
- phpMyAdmin: `wp-pma-{instance_name}`

## Getting Started

### Start the instance
```bash
cd {instance_name}
docker-compose up -d
```

### Access WordPress
http://localhost:{wp_port}

### Access phpMyAdmin
http://localhost:{pma_port}

### Stop the instance
```bash
docker-compose down
```

## Full Documentation
See the main README.md in the parent directory for complete documentation.
"""
    (instance_dir / 'README.md').write_text(readme_content)
    
    log_success(f"Instance created successfully!")
    log_info(f"Location: {instance_dir}")
    log_info(f"WordPress will be available at: http://localhost:{wp_port}")
    log_info(f"phpMyAdmin will be available at: http://localhost:{pma_port}")
    
    return True

def start_instance(instance_name: str) -> bool:
    """Start a WordPress instance"""
    
    script_dir = Path(__file__).parent.resolve()
    instance_dir = script_dir / 'instances' / instance_name
    
    if not instance_dir.exists():
        log_error(f"Instance '{instance_name}' not found")
        return False
    
    print_header(f"Starting WordPress Instance: {instance_name}")
    
    log_info("Starting Docker containers...")
    result = subprocess.run(
        COMPOSE_CMD.split() + ['up', '-d'],
        cwd=instance_dir
    )
    
    if result.returncode == 0:
        env_file = instance_dir / '.env'
        env_content = env_file.read_text()
        
        wp_port = None
        pma_port = None
        for line in env_content.split('\n'):
            if line.startswith('WP_PORT='):
                wp_port = line.split('=')[1]
            elif line.startswith('PMA_PORT='):
                pma_port = line.split('=')[1]
        
        log_success("Instance started successfully!")
        if wp_port:
            log_info(f"WordPress: http://localhost:{wp_port}")
        if pma_port:
            log_info(f"phpMyAdmin: http://localhost:{pma_port}")
        log_info("Waiting for containers to be ready (this may take a minute)...")
        
        return True
    else:
        log_error("Failed to start instance")
        return False

def fix_permissions(instance_name: str) -> bool:
    """Fix wp-content ownership/permissions (www-data:www-data, 755) inside a running instance.

    Resolves the WordPress "... is not writable by the server" upload error, which happens
    when files under wp-content (most often wp-content/uploads) end up owned by someone other
    than www-data -- e.g. after a migration import run via `docker exec` (root by default) or
    files copied in from the host as another user.
    """

    script_dir = Path(__file__).parent.resolve()
    instance_dir = script_dir / 'instances' / instance_name

    if not instance_dir.exists():
        log_error(f"Instance '{instance_name}' not found")
        return False

    print_header(f"Fixing Permissions: {instance_name}")

    container = f"wp-app-{instance_name}"

    if subprocess.run(['docker', 'exec', container, 'true'], capture_output=True).returncode != 0:
        log_error(f"Container '{container}' is not running. Start the instance first.")
        return False

    log_info("Setting ownership to www-data:www-data...")
    subprocess.run(['docker', 'exec', container, 'chown', '-R', 'www-data:www-data', '/var/www/html/wp-content'])

    log_info("Setting permissions to 755...")
    result = subprocess.run(['docker', 'exec', container, 'chmod', '-R', '755', '/var/www/html/wp-content'])

    if result.returncode == 0:
        log_success("Permissions fixed. wp-content is now owned by www-data:www-data (755).")
        return True
    else:
        log_error("Failed to fix permissions")
        return False

def stop_instance(instance_name: str) -> bool:
    """Stop a WordPress instance"""
    
    script_dir = Path(__file__).parent.resolve()
    instance_dir = script_dir / 'instances' / instance_name
    
    if not instance_dir.exists():
        log_error(f"Instance '{instance_name}' not found")
        return False
    
    print_header(f"Stopping WordPress Instance: {instance_name}")
    
    result = subprocess.run(
        COMPOSE_CMD.split() + ['down'],
        cwd=instance_dir
    )
    
    if result.returncode == 0:
        log_success("Instance stopped")
        return True
    else:
        log_error("Failed to stop instance")
        return False

def list_instances() -> bool:
    """List all WordPress instances"""
    
    print_header("WordPress Instances")
    
    script_dir = Path(__file__).parent.resolve()
    instances_dir = script_dir / 'instances'
    
    if not instances_dir.exists() or not list(instances_dir.glob('*')):
        log_warn("No instances found")
        return True
    
    for instance_path in sorted(instances_dir.glob('*')):
        if instance_path.is_dir():
            instance_name = instance_path.name
            env_file = instance_path / '.env'
            
            if env_file.exists():
                env_content = env_file.read_text()
                wp_port = None
                pma_port = None
                
                for line in env_content.split('\n'):
                    if line.startswith('WP_PORT='):
                        wp_port = line.split('=')[1]
                    elif line.startswith('PMA_PORT='):
                        pma_port = line.split('=')[1]
                
                # Check if running
                result = subprocess.run(
                    ['docker', 'ps', '--format', '{{.Labels}}'],
                    capture_output=True,
                    text=True
                )
                
                status = f"{Colors.GREEN}RUNNING{Colors.ENDC}" if f"com.wordpress.instance={instance_name}" in result.stdout else f"{Colors.RED}STOPPED{Colors.ENDC}"
                
                print(f"  Name: {Colors.CYAN}{instance_name}{Colors.ENDC}")
                print(f"  Status: {status}")
                if wp_port:
                    print(f"  WordPress: http://localhost:{wp_port}")
                if pma_port:
                    print(f"  phpMyAdmin: http://localhost:{pma_port}")
                print()
    
    return True

def backup_instance(instance_name: str) -> bool:
    """Backup a WordPress instance"""
    
    script_dir = Path(__file__).parent.resolve()
    instance_dir = script_dir / 'instances' / instance_name
    
    if not instance_dir.exists():
        log_error(f"Instance '{instance_name}' not found")
        return False
    
    print_header(f"Backing Up WordPress Instance: {instance_name}")
    
    timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    backup_dir = instance_dir / 'backups'
    
    # Get database credentials
    env_file = instance_dir / '.env'
    env_content = env_file.read_text()
    
    db_user = None
    db_password = None
    db_name = None
    
    for line in env_content.split('\n'):
        if line.startswith('MYSQL_USER='):
            db_user = line.split('=', 1)[1]
        elif line.startswith('MYSQL_PASSWORD='):
            db_password = line.split('=', 1)[1]
        elif line.startswith('MYSQL_DATABASE='):
            db_name = line.split('=', 1)[1]
    
    if not all([db_user, db_password, db_name]):
        log_error("Could not read database credentials from .env")
        return False
    
    db_container = f"wp-db-{instance_name}"
    
    # Backup database
    log_info("Backing up database...")
    db_backup_file = backup_dir / f"db-backup-{timestamp}.sql"
    
    result = subprocess.run(
        f'docker exec {db_container} mysqldump --no-tablespaces -u {db_user} -p{db_password} {db_name} > {db_backup_file}',
        shell=True,
        cwd=instance_dir
    )
    
    if result.returncode != 0:
        log_warn("Database backup may have failed")
    
    # Backup files
    log_info("Backing up WordPress files...")
    files_backup_file = backup_dir / f"files-backup-{timestamp}.tar.gz"
    
    result = subprocess.run(
        ['tar', '-czf', str(files_backup_file), 'wp-content/'],
        cwd=instance_dir
    )
    
    if result.returncode == 0:
        log_success("Backup completed successfully!")
        log_info(f"Database backup: backups/db-backup-{timestamp}.sql")
        log_info(f"Files backup: backups/files-backup-{timestamp}.tar.gz")
        return True
    else:
        log_error("Backup failed")
        return False

def delete_instance(instance_name: str) -> bool:
    """Delete a WordPress instance"""
    
    script_dir = Path(__file__).parent.resolve()
    instance_dir = script_dir / 'instances' / instance_name
    
    if not instance_dir.exists():
        log_error(f"Instance '{instance_name}' not found")
        return False
    
    print_header(f"Deleting WordPress Instance: {instance_name}")
    
    log_warn("This will:")
    log_warn("  - Stop all containers")
    log_warn("  - Remove volumes and networks")
    log_warn("  - Delete the instance directory")
    
    confirmation = input("\nType 'yes' to confirm deletion: ").strip()
    
    if confirmation != 'yes':
        log_info("Deletion cancelled")
        return False
    
    log_info("Stopping containers...")
    subprocess.run(
        COMPOSE_CMD.split() + ['down', '-v'],
        cwd=instance_dir,
        capture_output=True
    )
    
    log_info("Removing instance directory...")
    shutil.rmtree(instance_dir)
    
    log_success("Instance deleted")
    return True

def main():
    """Main entry point"""
    
    global COMPOSE_CMD
    COMPOSE_CMD = check_dependencies()
    
    parser = argparse.ArgumentParser(
        description='WordPress Docker Instance Manager',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s create mysite
  %(prog)s create mysite 8080 8081
  %(prog)s start mysite
  %(prog)s stop mysite
  %(prog)s list
  %(prog)s backup mysite
  %(prog)s delete mysite
  %(prog)s fix-permissions mysite
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')
    
    # Create command
    create_parser = subparsers.add_parser('create', help='Create a new WordPress instance')
    create_parser.add_argument('name', help='Instance name')
    create_parser.add_argument('pos_wp_port', nargs='?', type=int, default=None, help='WordPress port (positional)')
    create_parser.add_argument('pos_pma_port', nargs='?', type=int, default=None, help='phpMyAdmin port (positional)')
    create_parser.add_argument('--wp-port', dest='opt_wp_port', type=int, help='WordPress port (flag)')
    create_parser.add_argument('--pma-port', dest='opt_pma_port', type=int, help='phpMyAdmin port (flag)')
    create_parser.add_argument('--php-version', dest='opt_php_version', choices=SUPPORTED_PHP_VERSIONS, help='PHP version for the WordPress image')
    
    # Start command
    start_parser = subparsers.add_parser('start', help='Start an instance')
    start_parser.add_argument('name', help='Instance name')
    
    # Stop command
    stop_parser = subparsers.add_parser('stop', help='Stop an instance')
    stop_parser.add_argument('name', help='Instance name')

    # Fix permissions command
    fix_parser = subparsers.add_parser('fix-permissions', help='Fix wp-content upload permissions (www-data:www-data, 755)')
    fix_parser.add_argument('name', help='Instance name')
    
    # List command
    list_parser = subparsers.add_parser('list', help='List all instances')
    
    # Backup command
    backup_parser = subparsers.add_parser('backup', help='Backup an instance')
    backup_parser.add_argument('name', help='Instance name')
    
    # Delete command
    delete_parser = subparsers.add_parser('delete', help='Delete an instance')
    delete_parser.add_argument('name', help='Instance name')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    if args.command == 'create':
        wp_port = args.opt_wp_port if args.opt_wp_port is not None else args.pos_wp_port
        pma_port = args.opt_pma_port if args.opt_pma_port is not None else args.pos_pma_port
        success = create_instance(args.name, wp_port, pma_port, args.opt_php_version)
    elif args.command == 'start':
        success = start_instance(args.name)
    elif args.command == 'stop':
        success = stop_instance(args.name)
    elif args.command == 'fix-permissions':
        success = fix_permissions(args.name)
    elif args.command == 'list':
        success = list_instances()
    elif args.command == 'backup':
        success = backup_instance(args.name)
    elif args.command == 'delete':
        success = delete_instance(args.name)
    else:
        parser.print_help()
        return
    
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
