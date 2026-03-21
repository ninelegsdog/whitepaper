#!/bin/sh
# =============================================================================
# Paperclip Healthcheck Script
# =============================================================================
# This script performs comprehensive health checks for the Paperclip container
# Used by Docker HEALTHCHECK and for manual verification
# =============================================================================

set -e

# Configuration
PAPERCLIP_HOST="${PAPERCLIP_HOST:-localhost}"
PAPERCLIP_PORT="${PAPERCLIP_PORT:-3100}"
PAPERCLIP_PATH="${PAPERCLIP_PATH:-/health}"
TIMEOUT="${TIMEOUT:-5}"
MAX_RETRIES="${MAX_RETRIES:-3}"
DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-paperclip}"
DB_NAME="${DB_NAME:-paperclip}"

# Colors for output (disabled in production)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

log_info() {
    echo "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo "${GREEN}[OK]${NC} $*"
}

log_warning() {
    echo "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo "${RED}[ERROR]${NC} $*"
}

# =============================================================================
# Check 1: Paperclip HTTP Health Endpoint
# =============================================================================
check_paperclip_health() {
    log_info "Checking Paperclip health endpoint..."

    if command -v curl > /dev/null 2>&1; then
        HTTP_STATUS=$(curl -sf -m "$TIMEOUT" \
            "http://${PAPERCLIP_HOST}:${PAPERCLIP_PORT}${PAPERCLIP_PATH}" \
            -o /dev/null -w "%{http_code}" 2>/dev/null || echo "000")

        if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "204" ]; then
            log_success "Paperclip health check passed (HTTP $HTTP_STATUS)"
            return 0
        else
            log_error "Paperclip health check failed (HTTP $HTTP_STATUS)"
            return 1
        fi
    elif command -v wget > /dev/null 2>&1; then
        if wget -q -O /dev/null -T "$TIMEOUT" \
            "http://${PAPERCLIP_HOST}:${PAPERCLIP_PORT}${PAPERCLIP_PATH}"; then
            log_success "Paperclip health check passed"
            return 0
        else
            log_error "Paperclip health check failed"
            return 1
        fi
    else
        log_warning "Neither curl nor wget available, skipping HTTP check"
        return 0
    fi
}

# =============================================================================
# Check 2: Database Connectivity
# =============================================================================
check_database() {
    log_info "Checking database connectivity..."

    if command -v pg_isready > /dev/null 2>&1; then
        if pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t "$TIMEOUT" > /dev/null 2>&1; then
            log_success "Database is ready"
            return 0
        else
            log_error "Database is not ready"
            return 1
        fi
    elif command -v nc > /dev/null 2>&1; then
        if nc -z -w "$TIMEOUT" "$DB_HOST" "$DB_PORT"; then
            log_success "Database port is reachable"
            return 0
        else
            log_error "Cannot reach database port"
            return 1
        fi
    else
        log_warning "No database check tools available, skipping"
        return 0
    fi
}

# =============================================================================
# Check 3: Disk Space
# =============================================================================
check_disk_space() {
    log_info "Checking disk space..."

    # Get usage percentage of /paperclip or root
    local disk_usage=$(df -h /paperclip 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ -z "$disk_usage" ]; then
        disk_usage=$(df -h / 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')
    fi

    if [ -n "$disk_usage" ]; then
        if [ "$disk_usage" -lt 90 ]; then
            log_success "Disk space OK (${disk_usage}% used)"
            return 0
        elif [ "$disk_usage" -lt 95 ]; then
            log_warning "Disk space is running low (${disk_usage}% used)"
            return 0
        else
            log_error "Disk space critical (${disk_usage}% used)"
            return 1
        fi
    else
        log_warning "Could not determine disk usage"
        return 0
    fi
}

# =============================================================================
# Check 4: Memory Usage
# =============================================================================
check_memory() {
    log_info "Checking memory usage..."

    if [ -f /sys/fs/cgroup/memory/memory.usage_in_bytes ]; then
        local memory_usage=$(cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null)
        local memory_limit=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)
        
        if [ -n "$memory_usage" ] && [ -n "$memory_limit" ] && [ "$memory_limit" -gt 0 ]; then
            local usage_percent=$((memory_usage * 100 / memory_limit))
            if [ "$usage_percent" -lt 90 ]; then
                log_success "Memory OK (${usage_percent}% used)"
                return 0
            elif [ "$usage_percent" -lt 95 ]; then
                log_warning "Memory is running high (${usage_percent}% used)"
                return 0
            else
                log_error "Memory critical (${usage_percent}% used)"
                return 1
            fi
        fi
    fi
    
    log_success "Memory check skipped (cgroup not available)"
    return 0
}

# =============================================================================
# Check 5: Paperclip Data Directory
# =============================================================================
check_paperclip_dir() {
    log_info "Checking Paperclip data directory..."

    if [ -d "/paperclip" ]; then
        if [ -r "/paperclip" ] && [ -w "/paperclip" ]; then
            log_success "Paperclip data directory is accessible"
            return 0
        else
            log_error "Paperclip data directory is not writable"
            return 1
        fi
    else
        log_warning "Paperclip data directory does not exist"
        return 0
    fi
}

# =============================================================================
# Check 6: API Endpoint (detailed check)
# =============================================================================
check_api_endpoint() {
    log_info "Checking API endpoint..."

    if command -v curl > /dev/null 2>&1; then
        local api_response=$(curl -sf -m "$TIMEOUT" \
            "http://${PAPERCLIP_HOST}:${PAPERCLIP_PORT}/api/health" 2>/dev/null)
        
        if [ -n "$api_response" ]; then
            log_success "API endpoint is responding"
            return 0
        fi
    fi
    
    log_warning "API endpoint check skipped"
    return 0
}

# =============================================================================
# Main Health Check
# =============================================================================
main() {
    local failed=0
    local total=0

    log_info "=========================================="
    log_info "  Paperclip Container Health Check"
    log_info "=========================================="
    echo ""

    # Run all checks
    check_paperclip_health || failed=$((failed + 1))
    total=$((total + 1))

    check_database || failed=$((failed + 1))
    total=$((total + 1))

    check_disk_space || failed=$((failed + 1))
    total=$((total + 1))

    check_memory || failed=$((failed + 1))
    total=$((total + 1))

    check_paperclip_dir || failed=$((failed + 1))
    total=$((total + 1))

    check_api_endpoint || failed=$((failed + 1))
    total=$((total + 1))

    echo ""
    log_info "=========================================="
    log_info "  Results: $((total - failed))/$total checks passed"
    log_info "=========================================="

    if [ $failed -gt 0 ]; then
        log_error "Health check FAILED"
        exit 1
    else
        log_success "All health checks PASSED"
        exit 0
    fi
}

# Run main function
main "$@"
