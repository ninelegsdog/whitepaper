#!/bin/bash
# =============================================================================
# Paperclip Backup Script
# =============================================================================
# Creates full backup of all Paperclip data
# 
# Usage:
#   ./backup.sh              # Full backup
#   ./backup.sh --db-only    # Only database
#   ./backup.sh --redis-only # Only Redis
#   ./backup.sh --data-only  # Only paperclip data
#
# Environment:
#   BACKUP_DIR      - Directory for backups (default: ./backups)
#   BACKUP_RETENTION_DAYS - Days to keep backups (default: 90)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-${PROJECT_ROOT}/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-90}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="backup-${TIMESTAMP}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"
LOG_FILE="${BACKUP_DIR}/backup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

check_dependencies() {
    log "Checking dependencies..."
    
    local missing=()
    
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi
    
    if ! command -v gzip &> /dev/null; then
        missing+=("gzip")
    fi
    
    if ! command -v tar &> /dev/null; then
        missing+=("tar")
    fi
    
    if ! docker info &> /dev/null; then
        missing+=("docker daemon")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        exit 1
    fi
    
    log_success "All dependencies available"
}

create_backup_dirs() {
    log "Creating backup directories..."
    mkdir -p "$BACKUP_PATH"
    mkdir -p "$BACKUP_DIR"
    log_success "Directories created: $BACKUP_PATH"
}

backup_postgres() {
    log "Backing up PostgreSQL..."
    
    local db_container="paperclip-db"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${db_container}$"; then
        log_warning "PostgreSQL container not running, skipping..."
        return 0
    fi
    
    # Get credentials from environment
    local db_user="${POSTGRES_USER:-paperclip}"
    local db_name="${POSTGRES_DB:-paperclip}"
    
    # Create backup
    docker exec "$db_container" pg_dump -U "$db_user" -d "$db_name" | gzip > "${BACKUP_PATH}/paperclip-db.sql.gz"
    
    local size
    size=$(du -h "${BACKUP_PATH}/paperclip-db.sql.gz" | cut -f1)
    log_success "PostgreSQL backup created (${size})"
}

backup_redis() {
    log "Backing up Redis..."
    
    local redis_container="paperclip-redis"
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${redis_container}$"; then
        log_warning "Redis container not running, skipping..."
        return 0
    fi
    
    # Trigger SAVE and copy RDB file
    docker exec "$redis_container" redis-cli SAVE
    
    local rdb_path
    rdb_path=$(docker exec "$redis_container" redis-cli CONFIG GET dir | tail -n 1)
    docker cp "${redis_container}:${rdb_path}/dump.rdb" "${BACKUP_PATH}/dump.rdb"
    
    local size
    size=$(du -h "${BACKUP_PATH}/dump.rdb" | cut -f1)
    log_success "Redis backup created (${size})"
}

backup_paperclip_data() {
    log "Backing up Paperclip data..."
    
    local data_dir="${PROJECT_ROOT}/data/paperclip"
    
    if [ ! -d "$data_dir" ]; then
        log_warning "Paperclip data directory not found, skipping..."
        return 0
    fi
    
    tar -czf "${BACKUP_PATH}/paperclip-data.tar.gz" -C "${PROJECT_ROOT}" data/paperclip 2>/dev/null || true
    
    local size
    size=$(du -h "${BACKUP_PATH}/paperclip-data.tar.gz" 2>/dev/null | cut -f1 || echo "0")
    log_success "Paperclip data backup created (${size})"
}

backup_configs() {
    log "Backing up configuration files..."
    
    local configs_dir="${BACKUP_PATH}/configs"
    mkdir -p "$configs_dir"
    
    # Copy docker-compose files (without .env)
    cp "${PROJECT_ROOT}/docker-compose.yml" "${configs_dir}/" 2>/dev/null || true
    cp "${PROJECT_ROOT}/docker-compose.monitoring.yml" "${configs_dir}/" 2>/dev/null || true
    
    # Copy scripts
    mkdir -p "${configs_dir}/scripts/backup"
    cp -r "${PROJECT_ROOT}/scripts/backup/"*.sh "${configs_dir}/scripts/backup/" 2>/dev/null || true
    
    # Copy Makefile if exists
    cp "${PROJECT_ROOT}/Makefile" "${configs_dir}/" 2>/dev/null || true
    
    tar -czf "${BACKUP_PATH}/configs.tar.gz" -C "$configs_dir" .
    rm -rf "$configs_dir"
    
    local size
    size=$(du -h "${BACKUP_PATH}/configs.tar.gz" | cut -f1)
    log_success "Configuration backup created (${size})"
}

create_manifest() {
    log "Creating backup manifest..."
    
    local manifest="${BACKUP_DIR}/backup-manifest.json"
    local total_size
    total_size=$(du -sh "$BACKUP_PATH" | cut -f1)
    
    cat > "$manifest" << EOF
{
  "timestamp": "${TIMESTAMP}",
  "date": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "retention_days": ${RETENTION_DAYS},
  "backup_name": "${BACKUP_NAME}",
  "backup_path": "${BACKUP_PATH}",
  "total_size": "${total_size}",
  "components": {
    "database": $([ -f "${BACKUP_PATH}/paperclip-db.sql.gz" ] && echo "true" || echo "false"),
    "redis": $([ -f "${BACKUP_PATH}/dump.rdb" ] && echo "true" || echo "false"),
    "paperclip_data": $([ -f "${BACKUP_PATH}/paperclip-data.tar.gz" ] && echo "true" || echo "false"),
    "configs": $([ -f "${BACKUP_PATH}/configs.tar.gz" ] && echo "true" || echo "false")
  },
  "files": [
    $([ -f "${BACKUP_PATH}/paperclip-db.sql.gz" ] && echo "{ \"name\": \"paperclip-db.sql.gz\", \"size\": \"$(du -h "${BACKUP_PATH}/paperclip-db.sql.gz" | cut -f1)\" }" || echo ""),
    $([ -f "${BACKUP_PATH}/dump.rdb" ] && echo "{ \"name\": \"dump.rdb\", \"size\": \"$(du -h "${BACKUP_PATH}/dump.rdb" | cut -f1)\" }" || echo ""),
    $([ -f "${BACKUP_PATH}/paperclip-data.tar.gz" ] && echo "{ \"name\": \"paperclip-data.tar.gz\", \"size\": \"$(du -h "${BACKUP_PATH}/paperclip-data.tar.gz" | cut -f1)\" }" || echo ""),
    $([ -f "${BACKUP_PATH}/configs.tar.gz" ] && echo "{ \"name\": \"configs.tar.gz\", \"size\": \"$(du -h "${BACKUP_PATH}/configs.tar.gz" | cut -f1)\" }" || echo "")
  ]
}
EOF
    log_success "Manifest created"
}

cleanup_old_backups() {
    log "Cleaning up backups older than ${RETENTION_DAYS} days..."
    
    local deleted=0
    local freed_space=0
    
    # Find and remove old backups
    while IFS= read -r backup; do
        if [ -d "$backup" ]; then
            local size
            size=$(du -sb "$backup" | cut -f1)
            freed_space=$((freed_space + size))
            rm -rf "$backup"
            deleted=$((deleted + 1))
            log "Removed: $(basename "$backup")"
        fi
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup-*" -mtime +"${RETENTION_DAYS}" 2>/dev/null)
    
    # Convert freed space to human readable
    if [ $freed_space -gt 1073741824 ]; then
        freed_space=$(echo "scale=2; $freed_space/1073741824" | bc 2>/dev/null || echo "$((freed_space / 1073741824))")"GB"
    elif [ $freed_space -gt 1048576 ]; then
        freed_space=$(echo "scale=2; $freed_space/1048576" | bc 2>/dev/null || echo "$((freed_space / 1048576))")"MB"
    else
        freed_space="${freed_space}B"
    fi
    
    if [ $deleted -gt 0 ]; then
        log_success "Cleaned up ${deleted} old backup(s), freed ${freed_space}"
    else
        log "No old backups to clean up"
    fi
}

calculate_checksum() {
    log "Calculating checksum..."
    
    cd "$BACKUP_PATH"
    find . -type f -print0 | xargs -0 md5sum > md5sum.txt
    cd - > /dev/null
    
    log_success "Checksum created"
}

show_summary() {
    echo ""
    echo "============================================================"
    echo "                    BACKUP COMPLETE                         "
    echo "============================================================"
    echo "  Backup Name: ${BACKUP_NAME}"
    echo "  Backup Path: ${BACKUP_PATH}"
    echo "  Total Size:  $(du -sh "$BACKUP_PATH" | cut -f1)"
    echo "  Retention:   ${RETENTION_DAYS} days"
    echo ""
    echo "  Files:"
    [ -f "${BACKUP_PATH}/paperclip-db.sql.gz" ] && echo "    - paperclip-db.sql.gz"
    [ -f "${BACKUP_PATH}/dump.rdb" ] && echo "    - dump.rdb"
    [ -f "${BACKUP_PATH}/paperclip-data.tar.gz" ] && echo "    - paperclip-data.tar.gz"
    [ -f "${BACKUP_PATH}/configs.tar.gz" ] && echo "    - configs.tar.gz"
    echo ""
    echo "============================================================"
}

backup_mode="full"

while [[ $# -gt 0 ]]; do
    case $1 in
        --db-only)
            backup_mode="db"
            shift
            ;;
        --redis-only)
            backup_mode="redis"
            shift
            ;;
        --data-only)
            backup_mode="data"
            shift
            ;;
        --configs-only)
            backup_mode="configs"
            shift
            ;;
        --no-cleanup)
            no_cleanup=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --db-only       Backup only PostgreSQL"
            echo "  --redis-only    Backup only Redis"
            echo "  --data-only     Backup only Paperclip data"
            echo "  --configs-only  Backup only configuration"
            echo "  --no-cleanup    Skip old backup cleanup"
            echo "  --help, -h      Show this help"
            echo ""
            echo "Environment:"
            echo "  BACKUP_DIR           Backup directory (default: ./backups)"
            echo "  BACKUP_RETENTION_DAYS Days to keep backups (default: 90)"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

main() {
    log "============================================================"
    log "              PAPERCLIP BACKUP SCRIPT                      "
    log "============================================================"
    log "Backup mode: ${backup_mode}"
    log "Backup directory: ${BACKUP_DIR}"
    log "Retention: ${RETENTION_DAYS} days"
    
    check_dependencies
    create_backup_dirs
    
    case $backup_mode in
        full)
            backup_postgres
            backup_redis
            backup_paperclip_data
            backup_configs
            ;;
        db)
            backup_postgres
            ;;
        redis)
            backup_redis
            ;;
        data)
            backup_paperclip_data
            ;;
        configs)
            backup_configs
            ;;
    esac
    
    create_manifest
    calculate_checksum
    
    if [ "$no_cleanup" != true ]; then
        cleanup_old_backups
    fi
    
    show_summary
}

main "$@"
