#!/bin/bash
# =============================================================================
# Paperclip Restore Script
# =============================================================================
# Restores Paperclip from backup
# 
# Usage:
#   ./restore.sh backup-20260322-030000      # Restore from backup name
#   ./restore.sh --list                      # List available backups
#   ./restore.sh --verify backup-20260322    # Verify backup integrity
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-${PROJECT_ROOT}/backups}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_info() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v docker &> /dev/null; then
        log_error "docker not found"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "docker daemon not running"
        exit 1
    fi
    
    log_success "Dependencies OK"
}

list_backups() {
    log "Available backups in ${BACKUP_DIR}:"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null | grep -E '^backup-' )" ]; then
        log_warning "No backups found"
        exit 0
    fi
    
    printf "%-25s %10s %s\n" "BACKUP NAME" "SIZE" "DATE"
    echo "------------------------------------------------------------"
    
    for backup in "$BACKUP_DIR"/backup-*/; do
        if [ -d "$backup" ]; then
            local name
            local size
            local date
            name=$(basename "$backup")
            size=$(du -sh "$backup" 2>/dev/null | cut -f1 || echo "N/A")
            date=$(stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1 || echo "N/A")
            printf "%-25s %10s %s\n" "$name" "$size" "$date"
        fi
    done
    echo ""
}

verify_backup() {
    local backup_path="$1"
    
    log "Verifying backup: $backup_path"
    
    if [ ! -d "$backup_path" ]; then
        log_error "Backup not found: $backup_path"
        return 1
    fi
    
    local errors=0
    
    # Check md5sum
    if [ -f "${backup_path}/md5sum.txt" ]; then
        log "Checking file integrity..."
        cd "$backup_path"
        if md5sum -c md5sum.txt > /dev/null 2>&1; then
            log_success "File integrity verified"
        else
            log_error "File integrity check failed!"
            errors=$((errors + 1))
        fi
        cd - > /dev/null
    else
        log_warning "No md5sum file found, skipping integrity check"
    fi
    
    # Check required files
    log "Checking required files..."
    if [ -f "${backup_path}/paperclip-db.sql.gz" ] || [ -f "${backup_path}/dump.rdb" ] || [ -f "${backup_path}/paperclip-data.tar.gz" ] || [ -f "${backup_path}/configs.tar.gz" ]; then
        log_success "Backup contains data files"
    else
        log_error "No data files found in backup"
        errors=$((errors + 1))
    fi
    
    # Check manifest
    if [ -f "${BACKUP_DIR}/backup-manifest.json" ]; then
        log "Backup manifest found"
        python3 -m json.tool < "${BACKUP_DIR}/backup-manifest.json" > /dev/null 2>&1 || log_warning "Manifest is not valid JSON"
    fi
    
    if [ $errors -eq 0 ]; then
        log_success "Backup verification passed"
        return 0
    else
        log_error "Backup verification failed with $errors error(s)"
        return 1
    fi
}

stop_services() {
    log "Stopping Paperclip services..."
    
    cd "$PROJECT_ROOT"
    
    if [ -f "docker-compose.yml" ]; then
        docker compose -f docker-compose.yml stop 2>/dev/null || true
    fi
    
    log_success "Services stopped"
}

start_services() {
    log "Starting Paperclip services..."
    
    cd "$PROJECT_ROOT"
    
    if [ -f "docker-compose.yml" ]; then
        docker compose -f docker-compose.yml start 2>/dev/null || docker compose -f docker-compose.yml up -d 2>/dev/null || true
    fi
    
    log_success "Services started"
}

restore_postgres() {
    local backup_path="$1"
    local db_file="${backup_path}/paperclip-db.sql.gz"
    
    if [ ! -f "$db_file" ]; then
        log_warning "No PostgreSQL backup found, skipping..."
        return 0
    fi
    
    log "Restoring PostgreSQL..."
    
    local db_container="paperclip-db"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${db_container}$"; then
        log_error "PostgreSQL container not running"
        return 1
    fi
    
    local db_user="${POSTGRES_USER:-paperclip}"
    local db_name="${POSTGRES_DB:-paperclip}"
    
    # Drop existing connections
    docker exec "$db_container" psql -U "$db_user" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db_name' AND pid <> pg_backend_pid();" 2>/dev/null || true
    
    # Drop and recreate database
    docker exec "$db_container" psql -U "$db_user" -d postgres -c "DROP DATABASE IF EXISTS $db_name;" 2>/dev/null || true
    docker exec "$db_container" psql -U "$db_user" -d postgres -c "CREATE DATABASE $db_name;" 2>/dev/null || true
    
    # Restore backup
    gunzip -c "$db_file" | docker exec -i "$db_container" psql -U "$db_user" -d "$db_name"
    
    log_success "PostgreSQL restored"
}

restore_redis() {
    local backup_path="$1"
    local redis_file="${backup_path}/dump.rdb"
    
    if [ ! -f "$redis_file" ]; then
        log_warning "No Redis backup found, skipping..."
        return 0
    fi
    
    log "Restoring Redis..."
    
    local redis_container="paperclip-redis"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${redis_container}$"; then
        log_error "Redis container not running"
        return 1
    fi
    
    # Get Redis data directory
    local redis_dir
    redis_dir=$(docker exec "$redis_container" redis-cli CONFIG GET dir | tail -n 1)
    
    # Stop Redis to ensure safe copy
    docker exec "$redis_container" redis-cli SHUTDOWN NOSAVE 2>/dev/null || true
    sleep 2
    
    # Copy RDB file
    docker cp "$redis_file" "${redis_container}:${redis_dir}/dump.rdb"
    
    # Start Redis
    docker start "$redis_container" > /dev/null 2>&1
    
    sleep 2
    
    # Verify Redis is running
    if docker exec "$redis_container" redis-cli PING > /dev/null 2>&1; then
        log_success "Redis restored"
    else
        log_error "Redis failed to start"
        return 1
    fi
}

restore_paperclip_data() {
    local backup_path="$1"
    local data_file="${backup_path}/paperclip-data.tar.gz"
    
    if [ ! -f "$data_file" ]; then
        log_warning "No Paperclip data backup found, skipping..."
        return 0
    fi
    
    log "Restoring Paperclip data..."
    
    # Create backup of current data
    if [ -d "${PROJECT_ROOT}/data/paperclip" ]; then
        local backup_current
        backup_current="${PROJECT_ROOT}/data/paperclip.pre-restore.$(date +%Y%m%d-%H%M%S)"
        log "Backing up current data to: $backup_current"
        mv "${PROJECT_ROOT}/data/paperclip" "$backup_current"
    fi
    
    # Extract backup
    tar -xzf "$data_file" -C "${PROJECT_ROOT}/" 2>/dev/null || tar -xzf "$data_file" -C "/" 2>/dev/null || true
    
    log_success "Paperclip data restored"
}

restore_configs() {
    local backup_path="$1"
    local configs_file="${backup_path}/configs.tar.gz"
    
    if [ ! -f "$configs_file" ]; then
        log_warning "No configuration backup found, skipping..."
        return 0
    fi
    
    log "Configuration backup found (manual restore required)"
    log "Configs are in: $configs_file"
}

confirm_restore() {
    echo ""
    log_warning "============================================================"
    log_warning "                    WARNING!                                "
    log_warning "============================================================"
    log_warning "This will overwrite current data with backup contents."
    log_warning ""
    log_warning "BACKUP: $1"
    log_warning ""
    log_warning "Services will be stopped during restore."
    log_warning "============================================================"
    echo ""
    
    read -r -p "Type 'yes' to continue: " confirm
    if [ "$confirm" != "yes" ]; then
        log "Restore cancelled"
        exit 0
    fi
}

show_restore_summary() {
    local backup_path="$1"
    
    echo ""
    echo "============================================================"
    echo "                   RESTORE COMPLETE                         "
    echo "============================================================"
    echo "  Restored from: $(basename "$backup_path")"
    echo ""
    echo "  Services restarted"
    echo ""
    echo "  Next steps:"
    echo "    1. Check application logs: docker compose logs -f"
    echo "    2. Verify data integrity"
    echo "    3. Test application functionality"
    echo ""
    echo "============================================================"
}

main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <backup-name> [--force]"
        echo ""
        echo "Options:"
        echo "  <backup-name>   Backup folder name (e.g., backup-20260322-030000)"
        echo "  --list          List available backups"
        echo "  --verify        Verify backup integrity"
        echo "  --help, -h      Show this help"
        exit 1
    fi
    
    check_dependencies
    
    case $1 in
        --list|-l)
            list_backups
            exit 0
            ;;
        --verify|-v)
            if [ -z "$2" ]; then
                log_error "Backup name required"
                exit 1
            fi
            verify_backup "${BACKUP_DIR}/$2"
            exit $?
            ;;
        --help|-h)
            echo "Usage: $0 <backup-name> [options]"
            echo ""
            echo "Options:"
            echo "  --list, -l       List available backups"
            echo "  --verify, -v     Verify backup integrity"
            echo "  --force          Skip confirmation"
            echo "  --help, -h       Show this help"
            exit 0
            ;;
        *)
            backup_name="$1"
            ;;
    esac
    
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    if [ ! -d "$backup_path" ]; then
        log_error "Backup not found: $backup_path"
        echo ""
        echo "Available backups:"
        list_backups
        exit 1
    fi
    
    verify_backup "$backup_path" || {
        log_warning "Verification failed. Continue anyway? (y/N)"
        read -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    }
    
    local force=false
    if [ "$2" == "--force" ] || [ "$3" == "--force" ]; then
        force=true
    fi
    
    if [ "$force" != true ]; then
        confirm_restore "$backup_path"
    fi
    
    stop_services
    
    restore_postgres "$backup_path"
    restore_redis "$backup_path"
    restore_paperclip_data "$backup_path"
    restore_configs "$backup_path"
    
    start_services
    
    show_restore_summary "$backup_path"
}

main "$@"
