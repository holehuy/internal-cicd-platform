#!/bin/bash

###############################################################################
# Internal CI/CD Platform Backup Script
# 
# Description: Backup Jenkins, SonarQube data and configurations
# Usage: ./backup.sh
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

# Load environment
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

BACKUP_BASE_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backup}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_BASE_DIR/backup_$TIMESTAMP"

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

check_services() {
    log_info "Checking if services are running..."
    
    if ! docker ps | grep -q "internal-jenkins"; then
        log_error "Jenkins is not running. Please start the platform first."
        exit 1
    fi
    
    if ! docker ps | grep -q "internal-sonarqube"; then
        log_error "SonarQube is not running. Please start the platform first."
        exit 1
    fi
    
    log_success "Services are running."
}

create_backup_dir() {
    log_info "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
}

backup_jenkins() {
    log_info "Backing up Jenkins data..."
    
    # Create Jenkins backup
    docker exec internal-jenkins tar czf /tmp/jenkins_backup.tar.gz \
        -C /var/jenkins_home \
        --exclude='workspace/*' \
        --exclude='caches/*' \
        --exclude='logs/*' \
        .
    
    # Copy backup to host
    docker cp internal-jenkins:/tmp/jenkins_backup.tar.gz "$BACKUP_DIR/"
    
    # Cleanup
    docker exec internal-jenkins rm /tmp/jenkins_backup.tar.gz
    
    log_success "Jenkins data backed up!"
}

backup_sonarqube() {
    log_info "Backing up SonarQube data..."
    
    # Backup SonarQube data directory
    docker exec internal-sonarqube tar czf /tmp/sonarqube_data.tar.gz \
        -C /opt/sonarqube/data .
    
    docker cp internal-sonarqube:/tmp/sonarqube_data.tar.gz "$BACKUP_DIR/"
    docker exec internal-sonarqube rm /tmp/sonarqube_data.tar.gz
    
    # Backup SonarQube extensions
    docker exec internal-sonarqube tar czf /tmp/sonarqube_extensions.tar.gz \
        -C /opt/sonarqube/extensions .
    
    docker cp internal-sonarqube:/tmp/sonarqube_extensions.tar.gz "$BACKUP_DIR/"
    docker exec internal-sonarqube rm /tmp/sonarqube_extensions.tar.gz
    
    log_success "SonarQube data backed up!"
}

backup_database() {
    log_info "Backing up PostgreSQL database..."
    
    # Backup database
    docker exec sonarqube-postgres pg_dump \
        -U "${SONAR_DB_USER:-sonar}" \
        -d "${SONAR_DB_NAME:-sonarqube}" \
        -F c \
        -f /tmp/sonarqube_db.dump
    
    docker cp sonarqube-postgres:/tmp/sonarqube_db.dump "$BACKUP_DIR/"
    docker exec sonarqube-postgres rm /tmp/sonarqube_db.dump
    
    log_success "Database backed up!"
}

backup_configs() {
    log_info "Backing up configuration files..."
    
    # Copy configuration files
    cp -r "$PROJECT_ROOT/env" "$BACKUP_DIR/"
    cp -r "$PROJECT_ROOT/jenkins/casc" "$BACKUP_DIR/"
    cp "$PROJECT_ROOT/docker-compose.yml" "$BACKUP_DIR/"
    
    # Remove sensitive data from env backup
    sed -i 's/PASSWORD=.*/PASSWORD=***REDACTED***/g' "$BACKUP_DIR/env/platform.env" 2>/dev/null || true
    
    log_success "Configuration files backed up!"
}

create_backup_info() {
    log_info "Creating backup information file..."
    
    cat > "$BACKUP_DIR/backup_info.txt" <<EOF
Backup Information
==================
Date: $(date)
Platform Version: 1.0.0
Hostname: $(hostname)

Services:
- Jenkins Version: $(docker exec internal-jenkins cat /var/jenkins_home/config.xml | grep '<version>' | sed 's/.*<version>\(.*\)<\/version>.*/\1/' || echo "Unknown")
- SonarQube Version: $(docker exec internal-sonarqube cat /opt/sonarqube/lib/sonar-application-*.jar | head -1 | grep -oP '\d+\.\d+\.\d+' || echo "Unknown")

Backup Contents:
- jenkins_backup.tar.gz      : Jenkins home directory
- sonarqube_data.tar.gz      : SonarQube data
- sonarqube_extensions.tar.gz: SonarQube plugins and extensions
- sonarqube_db.dump          : PostgreSQL database dump
- env/                       : Environment configuration (passwords redacted)
- casc/                      : Jenkins Configuration as Code
- docker-compose.yml         : Docker Compose configuration

Restore Command:
./scripts/restore.sh $BACKUP_DIR
EOF
    
    log_success "Backup info created!"
}

compress_backup() {
    log_info "Compressing backup..."
    
    cd "$BACKUP_BASE_DIR"
    tar czf "backup_$TIMESTAMP.tar.gz" "backup_$TIMESTAMP"
    
    # Remove uncompressed backup
    rm -rf "backup_$TIMESTAMP"
    
    log_success "Backup compressed: backup_$TIMESTAMP.tar.gz"
}

cleanup_old_backups() {
    local retention_days="${BACKUP_RETENTION_DAYS:-30}"
    
    log_info "Cleaning up backups older than $retention_days days..."
    
    find "$BACKUP_BASE_DIR" -name "backup_*.tar.gz" -type f -mtime +$retention_days -delete
    
    log_success "Old backups cleaned up!"
}

show_summary() {
    local backup_size=$(du -sh "$BACKUP_BASE_DIR/backup_$TIMESTAMP.tar.gz" | cut -f1)
    
    echo
    echo "=========================================="
    log_success "Backup completed successfully!"
    echo "=========================================="
    echo
    echo "📦 Backup Details:"
    echo "  Location: $BACKUP_BASE_DIR/backup_$TIMESTAMP.tar.gz"
    echo "  Size: $backup_size"
    echo "  Timestamp: $TIMESTAMP"
    echo
    echo "🔄 Restore Command:"
    echo "  ./scripts/restore.sh $BACKUP_BASE_DIR/backup_$TIMESTAMP.tar.gz"
    echo
}

main() {
    echo "=========================================="
    echo "CI/CD Platform Backup"
    echo "=========================================="
    echo
    
    check_services
    create_backup_dir
    backup_jenkins
    backup_sonarqube
    backup_database
    backup_configs
    create_backup_info
    compress_backup
    cleanup_old_backups
    show_summary
}

main