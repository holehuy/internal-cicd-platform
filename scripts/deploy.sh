#!/bin/bash

###############################################################################
# Internal CI/CD Platform Deployment Script
# 
# Description: Deploy Jenkins and SonarQube platform
# Usage: ./deploy.sh [options]
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/env/platform.env"

# Functions
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

check_requirements() {
    log_info "Checking requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if .env file exists
    if [ ! -f "$ENV_FILE" ]; then
        log_error "Environment file not found: $ENV_FILE"
        log_info "Please copy env/platform.env.example to env/platform.env and configure it."
        exit 1
    fi
    
    log_success "All requirements met!"
}

validate_env() {
    log_info "Validating environment configuration..."
    
    source "$ENV_FILE"
    
    # Check critical variables
    local required_vars=(
        "JENKINS_ADMIN_PASSWORD"
        "SONAR_ADMIN_PASSWORD"
        "POSTGRES_PASSWORD"
    )
    
    local missing_vars=0
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Required variable $var is not set in $ENV_FILE"
            missing_vars=$((missing_vars + 1))
        fi
    done
    
    if [ $missing_vars -gt 0 ]; then
        log_error "$missing_vars required variable(s) missing. Please configure them in $ENV_FILE"
        exit 1
    fi
    
    # Check for default passwords
    if [ "$JENKINS_ADMIN_PASSWORD" = "changeme123!" ] || [ "$SONAR_ADMIN_PASSWORD" = "changeme123!" ]; then
        log_warning "You are using default passwords. Please change them in $ENV_FILE for production use!"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_success "Environment validation passed!"
}

setup_directories() {
    log_info "Setting up directories..."
    
    # Create necessary directories
    mkdir -p "$PROJECT_ROOT/backup"
    mkdir -p "$PROJECT_ROOT/nginx/ssl"
    
    log_success "Directories created!"
}

build_images() {
    log_info "Building custom images..."

    cd "$PROJECT_ROOT"
    source "$ENV_FILE"

    # Build Jenkins custom image with plugins
    log_info "Building Jenkins image with plugins (this may take a few minutes)..."
    docker compose build jenkins

    if [ $? -ne 0 ]; then
        log_error "Failed to build Jenkins image"
        exit 1
    fi

    log_success "Jenkins image built successfully!"
}

pull_images() {
    log_info "Pulling base Docker images..."

    cd "$PROJECT_ROOT"
    source "$ENV_FILE"

    # Pull only images that don't need to be built
    docker compose pull sonarqube sonarqube-db nginx

    log_success "Base images pulled!"
}

start_services() {
    log_info "Starting services..."

    cd "$PROJECT_ROOT"
    source "$ENV_FILE"
    docker compose up -d

    log_success "Services started!"
}

wait_for_services() {
    log_info "Waiting for services to be healthy..."
    
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker compose ps | grep -q "healthy"; then
            local jenkins_healthy=$(docker inspect --format='{{.State.Health.Status}}' internal-jenkins 2>/dev/null || echo "starting")
            local sonar_healthy=$(docker inspect --format='{{.State.Health.Status}}' internal-sonarqube 2>/dev/null || echo "starting")
            
            if [ "$jenkins_healthy" = "healthy" ] && [ "$sonar_healthy" = "healthy" ]; then
                log_success "All services are healthy!"
                return 0
            fi
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    echo
    log_warning "Services took longer than expected to become healthy. Check logs with: docker compose logs"
}

show_info() {
    source "$ENV_FILE"
    
    echo
    echo "=========================================="
    log_success "Internal CI/CD Platform Deployed!"
    echo "=========================================="
    echo
    echo "📋 Access Information:"
    echo
    echo "Jenkins:"
    echo "  URL: http://localhost:${JENKINS_PORT:-8080}"
    echo "  Username: ${JENKINS_ADMIN_USER:-admin}"
    echo "  Password: ${JENKINS_ADMIN_PASSWORD}"
    echo
    echo "SonarQube:"
    echo "  URL: http://localhost:${SONARQUBE_PORT:-9000}"
    echo "  Username: admin"
    echo "  Password: admin (default - MUST change after first login)"
    echo
    echo "⚠️  Note: SonarQube version 9.9.8 (LTS) may show 'no longer active' warning."
    echo "    This is normal. The Community Edition continues to work fine."
    echo
    echo "📚 Next Steps:"
    echo "  1. Access Jenkins and verify configuration"
    echo "  2. Access SonarQube and change default password"
    echo "  3. Create SonarQube token for Jenkins integration"
    echo "  4. Read documentation in docs/ folder"
    echo
    echo "🔧 Useful Commands:"
    echo "  Check status:  docker compose ps"
    echo "  View logs:     docker compose logs -f [service]"
    echo "  Stop platform: ./scripts/stop.sh"
    echo "  Backup data:   ./scripts/backup.sh"
    echo
}

main() {
    echo "=========================================="
    echo "Internal CI/CD Platform Deployment"
    echo "=========================================="
    echo

    check_requirements
    validate_env
    setup_directories
    build_images
    pull_images
    start_services
    wait_for_services
    show_info
}

# Run main function
main