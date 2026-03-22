#!/bin/bash
# =============================================================================
# Paperclip Validation Script
# =============================================================================
# Validates configuration before deployment
# 
# Usage:
#   ./validate.sh
#   ./validate.sh --strict
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
STRICT_MODE=false

if [ "${1:-}" == "--strict" ]; then
    STRICT_MODE=true
fi

log_info() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ERRORS=$((ERRORS + 1))
}

header() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}============================================================${NC}"
}

# Required files check
check_required_files() {
    header "Required Files"
    
    local files=(
        "docker-compose.yml"
        "docker-compose.monitoring.yml"
        ".env"
        "opencode/Dockerfile.opencode"
        "opencode/opencode-config.json"
    )
    
    local missing=0
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            log_success "$file exists"
        else
            log_error "$file missing"
            missing=$((missing + 1))
        fi
    done
    
    if [ $missing -gt 0 ]; then
        echo ""
        log_error "Missing $missing required file(s)"
        return 1
    fi
}

# Docker check
check_docker() {
    header "Docker Environment"
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker not installed"
        return 1
    fi
    log_success "Docker installed"
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon not running"
        return 1
    fi
    log_success "Docker daemon running"
    
    local version
    version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    log_info "Docker version: $version"
}

# Port availability
check_ports() {
    header "Port Availability"
    
    local ports=(3100 4096 5432 6379)
    local monitoring_ports=(9090 3000 9093 9100 8080 3101)
    local all_ports=("${ports[@]}" "${monitoring_ports[@]}")
    
    # Note: This check may not work in all environments (Docker, WSL, etc.)
    if command -v netstat >/dev/null 2>&1 || command -v ss >/dev/null 2>&1; then
        for port in "${all_ports[@]}"; do
            if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
                log_warning "Port $port is in use"
            else
                log_success "Port $port available"
            fi
        done
    else
        log_warning "netstat/ss not available, skipping port check"
    fi
}

# Environment variables check
check_env() {
    header "Environment Variables"
    
    if [ ! -f ".env" ]; then
        log_error ".env file not found"
        log_info "Copy .env.example to .env and fill in values"
        return 1
    fi
    log_success ".env file exists"
    
    source .env 2>/dev/null || true
    
    local required_vars=(
        "POSTGRES_USER"
        "POSTGRES_PASSWORD"
        "POSTGRES_DB"
        "GROQ_API_KEY"
        "OPENCODE_API_PASSWORD"
    )
    
    local missing=0
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "$var not set in .env"
            missing=$((missing + 1))
        else
            log_success "$var is set"
        fi
    done
    
    # Check for placeholder values
    if [ "$STRICT_MODE" = true ]; then
        if [[ "$POSTGRES_PASSWORD" == *"changeme"* ]] || [[ "$OPENCODE_API_PASSWORD" == *"changeme"* ]]; then
            log_warning "Using placeholder password - change for production!"
        fi
    fi
    
    if [ $missing -gt 0 ]; then
        echo ""
        log_error "$missing required variable(s) not set"
        return 1
    fi
}

# Directory structure
check_directories() {
    header "Directory Structure"
    
    local dirs=(
        "data"
        "data/paperclip"
        "logs"
        "backups"
    )
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_success "$dir exists"
        else
            log_info "Creating $dir..."
            mkdir -p "$dir"
            log_success "$dir created"
        fi
    done
}

# Docker compose validation
check_compose() {
    header "Docker Compose Validation"
    
    log_info "Validating docker-compose.yml..."
    if docker compose -f docker-compose.yml config --quiet 2>/dev/null; then
        log_success "docker-compose.yml is valid"
    else
        log_error "docker-compose.yml has errors"
        docker compose -f docker-compose.yml config 2>&1 | head -10
        return 1
    fi
    
    log_info "Validating docker-compose.monitoring.yml..."
    if docker compose -f docker-compose.monitoring.yml config --quiet 2>/dev/null; then
        log_success "docker-compose.monitoring.yml is valid"
    else
        log_warning "docker-compose.monitoring.yml has errors (monitoring optional)"
    fi
}

# Service connectivity
check_connectivity() {
    header "Service Connectivity"
    
    # Check if containers are running
    local containers
    containers=$(docker ps --filter "name=paperclip" --format "{{.Names}}" 2>/dev/null)
    
    if [ -z "$containers" ]; then
        log_warning "No Paperclip containers running (start with 'make up')"
        return 0
    fi
    
    log_info "Checking running containers..."
    echo "$containers" | while read -r container; do
        local status
        status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
        if [ "$status" = "healthy" ]; then
            log_success "$container: healthy"
        elif [ "$status" = "starting" ]; then
            log_info "$container: starting..."
        else
            log_warning "$container: $status"
        fi
    done
}

# Backup system check
check_backup_system() {
    header "Backup System"
    
    if [ -d "scripts/backup" ]; then
        log_success "Backup scripts directory exists"
        
        local scripts=(backup.sh restore.sh list-backups.sh cleanup.sh)
        for script in "${scripts[@]}"; do
            if [ -x "scripts/backup/$script" ]; then
                log_success "scripts/backup/$script is executable"
            elif [ -f "scripts/backup/$script" ]; then
                log_info "Making scripts/backup/$script executable..."
                chmod +x "scripts/backup/$script"
                log_success "scripts/backup/$script is now executable"
            else
                log_warning "scripts/backup/$script not found"
            fi
        done
    else
        log_warning "Backup scripts directory not found"
    fi
    
    if [ -d "backups" ]; then
        log_success "Backups directory exists"
    else
        log_info "Creating backups directory..."
        mkdir -p backups
        log_success "Backups directory created"
    fi
}

# Security checks
check_security() {
    header "Security Checks"
    
    # Check if .env is in .gitignore
    if [ -f ".gitignore" ]; then
        if grep -q "^\.env$" .gitignore 2>/dev/null; then
            log_success ".env is in .gitignore"
        else
            log_warning ".env not in .gitignore"
        fi
        
        if grep -q "^backups/" .gitignore 2>/dev/null; then
            log_success "backups/ is in .gitignore"
        else
            log_warning "backups/ not in .gitignore"
        fi
    else
        log_warning ".gitignore not found"
    fi
    
    # Check for exposed secrets in docker-compose
    if grep -r "password" docker-compose*.yml 2>/dev/null | grep -v "\${.*}" | grep -qE "(password|PASSWORD).*[:=].*[a-zA-Z0-9]"; then
        log_warning "Possible hardcoded password in docker-compose files"
    else
        log_success "No hardcoded passwords found"
    fi
}

# Resource availability
check_resources() {
    header "System Resources"
    
    local mem_total
    local mem_gb
    local disk_avail
    mem_total=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    mem_gb=$((mem_total / 1024 / 1024))
    
    log_info "Total memory: ${mem_gb}GB"
    
    if [ "$mem_gb" -ge 4 ]; then
        log_success "Memory sufficient for Paperclip"
    elif [ "$mem_gb" -ge 2 ]; then
        log_warning "Low memory (${mem_gb}GB) - may cause issues"
    else
        log_error "Insufficient memory (${mem_gb}GB) - need at least 4GB"
    fi
    
    disk_avail=$(df -BG "$PROJECT_ROOT" 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G')
    log_info "Available disk space: ${disk_avail}GB"
    
    if [ "$disk_avail" -ge 10 ]; then
        log_success "Disk space sufficient"
    elif [ "$disk_avail" -ge 5 ]; then
        log_warning "Low disk space (${disk_avail}GB)"
    else
        log_error "Critical disk space (${disk_avail}GB) - need at least 10GB"
    fi
}

# Print summary
print_summary() {
    header "Validation Summary"
    
    echo ""
    if [ $ERRORS -eq 0 ]; then
        echo -e "${GREEN}✓ All checks passed!${NC}"
    else
        echo -e "${RED}✗ $ERRORS error(s) found${NC}"
    fi
    
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ $WARNINGS warning(s)${NC}"
    fi
    
    echo ""
    echo "Next steps:"
    if [ $ERRORS -eq 0 ]; then
        echo "  1. Start services:     make up"
        echo "  2. View logs:           make logs"
        echo "  3. Create backup:       make backup"
        echo ""
        echo "  Or start with monitoring:"
        echo "  4. Start monitoring:    make monitoring-up"
    else
        echo "  Fix errors above before starting services."
    fi
    echo ""
}

# Main
main() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           Paperclip Configuration Validator              ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    
    check_required_files || true
    check_docker || true
    check_env || true
    check_directories
    check_compose || true
    check_backup_system
    check_security
    check_resources
    
    print_summary
    
    if [ $ERRORS -gt 0 ]; then
        exit 1
    fi
    
    exit 0
}

main "$@"
