#!/bin/bash

###############################################################################
# Internal CI/CD Platform Restore Script
# 
# Description: Restore Jenkins and SonarQube data from backup
# Usage: ./restore.sh <backup-file.tar.gz>
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/env/platform.env"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    echo "Usage: ./restore.sh <backup-file.tar.gz>"
    echo
    echo "Example:"
    echo "  ./restore.sh /backup/backup_20231215_120000.tar.gz"
    echo
}

check_backup_file() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        log_error "Backup file not specified!"
        show_usage
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    log_success "Backup file found: $backup_file"
}

confirm_restore() {
    log_warning "WARNING: This will restore data from backup and overwrite current data!"
    log_warning "All current Jenkins and SonarQube data will be replaced!"
    echo
    read -p "Are you sure you want to continue? Type 'RESTORE' to confirm: " confirm
    
    if [ "$confirm" != "RESTORE" ]; then
        log_info "Operation cancelled."
        exit 0
    fi
}

stop_services() {
    log_info "Stopping services..."
    cd "$PROJECT_ROOT"
    docker-compose stop jenkins sonarqube
    log_success "Services stopped!"
}

extract_backup() {
    local backup_file=$1
    local temp_dir="/tmp/cicd-restore-$$"
    
    log_info "Extracting backup to temporary directory..."
    mkdir -p "$temp_dir"
    tar xzf "$backup_file" -C "$temp_dir"
    
    # Find the extracted directory
    BACKUP_DIR=$(find "$temp_dir" -maxdepth 1 -type d -name "backup_*" | head -1)
    
    if [ -z "$BACKUP_DIR" ]; then
        log_error "Could not find backup directory in archive!"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    log_success "Backup extracted to: $BACKUP_DIR"
}

restore_jenkins() {
    log_info "Restoring Jenkins data..."
    
    if [ ! -f "$BACKUP_DIR/jenkins_backup.tar.gz" ]; then
        log_error "Jenkins backup not found in archive!"
        exit 1
    fi
    
    # Copy backup into container
    docker cp "$BACKUP_DIR/jenkins_backup.tar.gz" internal-jenkins:/tmp/
    
    # Extract inside container
    docker exec internal-jenkins bash -c "
        rm -rf /var/jenkins_home.bak
        mv /var/jenkins_home /var/jenkins_home.bak
        mkdir -p /var/jenkins_home
        tar xzf /tmp/jenkins_backup.tar.gz -C /var/jenkins_home
        rm /tmp/jenkins_backup.tar.gz
        chown -R jenkins:jenkins /var/jenkins_home
    "
    
    log_success "Jenkins data restored!"
}

restore_sonarqube() {
    log_info "Restoring SonarQube data..."
    
    if [ ! -f "$BACKUP_DIR/sonarqube_data.tar.gz" ] || [ ! -f "$BACKUP_DIR/sonarqube_extensions.tar.gz" ]; then
        log_error "SonarQube backup files not found in archive!"
        exit 1
    fi
    
    # Restore data
    docker cp "$BACKUP_DIR/sonarqube_data.tar.gz" internal-sonarqube:/tmp/
    docker exec internal-sonarqube bash -c "
        rm -rf /opt/sonarqube/data.bak
        mv /opt/sonarqube/data /opt/sonarqube/data.bak
        mkdir -p /opt/sonarqube/data
        tar xzf /tmp/sonarqube_data.tar.gz -C /opt/sonarqube/data
        rm /tmp/sonarqube_data.tar.gz
        chown -R sonarqube:sonarqube /opt/sonarqube/data
    "
    
    # Restore extensions
    docker cp "$BACKUP_DIR/sonarqube_extensions.tar.gz" internal-sonarqube:/tmp/
    docker exec internal-sonarqube bash -c "
        rm -rf /opt/sonarqube/extensions.bak
        mv /opt/sonarqube/extensions /opt/sonarqube/extensions.bak
        mkdir -p /opt/sonarqube/extensions
        tar xzf /tmp/sonarqube_extensions.tar.gz -C /opt/sonarqube/extensions
        rm /tmp/sonarqube_extensions.tar.gz
        chown -R sonarqube:sonarqube /opt/sonarqube/extensions
    "
    
    log_success "SonarQube data restored!"
}

restore_database() {
    log_info "Restoring PostgreSQL database..."
    
    if [ ! -f "$BACKUP_DIR/sonarqube_db.dump" ]; then
        log_error "Database backup not found in archive!"
        exit 1
    fi
    
    # Load environment
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
    fi
    
    # Copy dump file to container
    docker cp "$BACKUP_DIR/sonarqube_db.dump" sonarqube-postgres:/tmp/
    
    # Drop and recreate database
    docker exec sonarqube-postgres psql -U "${SONAR_DB_USER:-sonar}" -c "DROP DATABASE IF EXISTS ${SONAR_DB_NAME:-sonarqube};"
    docker exec sonarqube-postgres psql -U "${SONAR_DB_USER:-sonar}" -c "CREATE DATABASE ${SONAR_DB_NAME:-sonarqube};"
    
    # Restore database
    docker exec sonarqube-postgres pg_restore \
        -U "${SONAR_DB_USER:-sonar}" \
        -d "${SONAR_DB_NAME:-sonarqube}" \
        -c \
        /tmp/sonarqube_db.dump
    
    docker exec sonarqube-postgres rm /tmp/sonarqube_db.dump
    
    log_success "Database restored!"
}

restore_configs() {
    log_info "Restoring configuration files..."
    
    # Backup current configs
    if [ -f "$ENV_FILE" ]; then
        cp "$ENV_FILE" "$ENV_FILE.bak.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Note: We don't restore env file as it may contain server-specific settings
    # Users should manually merge if needed
    
    log_warning "Configuration files NOT restored automatically."
    log_info "Please review backup configs in: $BACKUP_DIR/env/"
    log_info "Current env backup saved to: $ENV_FILE.bak.*"
}

start_services() {
    log_info "Starting services..."
    cd "$PROJECT_ROOT"
    docker-compose start jenkins sonarqube
    
    log_info "Waiting for services to start..."
    sleep 10
    
    log_success "Services started!"
}

cleanup() {
    log_info "Cleaning up temporary files..."
    if [ -n "$BACKUP_DIR" ] && [ -d "$(dirname "$BACKUP_DIR")" ]; then
        rm -rf "$(dirname "$BACKUP_DIR")"
    fi
    log_success "Cleanup complete!"
}

show_summary() {
    echo
    echo "=========================================="
    log_success "Restore completed successfully!"
    echo "=========================================="
    echo
    echo "📋 Next Steps:"
    echo "  1. Verify Jenkins: http://localhost:8080"
    echo "  2. Verify SonarQube: http://localhost:9000"
    echo "  3. Check application logs for any errors"
    echo "  4. Review and merge configuration files if needed"
    echo
    echo "🔧 Useful Commands:"
    echo "  View logs:     docker-compose logs -f [service]"
    echo "  Check status:  docker-compose ps"
    echo
    echo "⚠️  If you encounter issues:"
    echo "  1. Check logs: docker-compose logs"
    echo "  2. Restart services: docker-compose restart"
    echo "  3. Contact support if problems persist"
    echo
}

main() {
    local backup_file=$1
    
    echo "=========================================="
    echo "CI/CD Platform Restore"
    echo "=========================================="
    echo
    
    check_backup_file "$backup_file"
    confirm_restore
    stop_services
    extract_backup "$backup_file"
    restore_jenkins
    restore_sonarqube
    restore_database
    restore_configs
    start_services
    cleanup
    show_summary
}

# Trap errors
trap 'log_error "An error occurred during restore. Please check the logs."; cleanup; exit 1' ERR

main "$@"