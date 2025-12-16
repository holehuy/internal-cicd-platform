#!/bin/bash

###############################################################################
# Internal CI/CD Platform Stop Script
# 
# Description: Gracefully stop all platform services
# Usage: ./stop.sh [--remove-volumes]
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
    echo "Usage: ./stop.sh [OPTIONS]"
    echo
    echo "Options:"
    echo "  --remove-volumes    Remove all data volumes (WARNING: This deletes all data!)"
    echo "  -h, --help         Show this help message"
    echo
}

main() {
    local remove_volumes=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --remove-volumes)
                remove_volumes=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    echo "=========================================="
    echo "Stopping CI/CD Platform"
    echo "=========================================="
    echo
    
    cd "$PROJECT_ROOT"
    
    if [ "$remove_volumes" = true ]; then
        log_warning "WARNING: This will remove all data volumes!"
        log_warning "All Jenkins and SonarQube data will be permanently deleted!"
        echo
        read -p "Are you absolutely sure? Type 'DELETE' to confirm: " confirm
        
        if [ "$confirm" != "DELETE" ]; then
            log_info "Operation cancelled."
            exit 0
        fi
        
        log_info "Stopping services and removing volumes..."
        docker-compose down -v
        log_success "Services stopped and volumes removed!"
    else
        log_info "Stopping services (data will be preserved)..."
        docker-compose down
        log_success "Services stopped! Data volumes are preserved."
        echo
        log_info "To start again: ./scripts/deploy.sh"
        log_info "To remove data: ./stop.sh --remove-volumes"
    fi
}

main "$@"