#!/bin/bash
# =============================================================================
# Paperclip Backup Cleanup Script
# =============================================================================
# Cleans up old backups based on retention policy
# 
# Usage:
#   ./cleanup.sh                    # Interactive mode
#   ./cleanup.sh --dry-run         # Show what would be deleted
#   ./cleanup.sh --days 30        # Override retention days
#   ./cleanup.sh --space 5GB       # Delete to free space
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-${PROJECT_ROOT}/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-90}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

format_size() {
    local size="$1"
    if [ "$size" -gt 1073741824 ]; then
        echo "$(echo "scale=2; $size/1073741824" | bc 2>/dev/null || echo "$((size / 1073741824))")GB"
    elif [ "$size" -gt 1048576 ]; then
        echo "$(echo "scale=2; $size/1048576" | bc 2>/dev/null || echo "$((size / 1048576))")MB"
    elif [ "$size" -gt 1024 ]; then
        echo "$((size / 1024))KB"
    else
        echo "${size}B"
    fi
}

get_backup_age() {
    local backup_path="$1"
    local age_seconds
    age_seconds=$(($(date +%s) - $(stat -c %Y "$backup_path" 2>/dev/null || echo "0")))
    echo $((age_seconds / 86400))
}

find_old_backups() {
    local days="$1"
    
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup-*" -mtime +"${days}" 2>/dev/null
}

find_large_backups() {
    local target_space_bytes="$1"
    
    # Find backups sorted by size (largest first) that would free enough space
    du -sb "$BACKUP_DIR"/backup-* 2>/dev/null | sort -rn | while read -r size path; do
        if [ "$target_space_bytes" -gt 0 ]; then
            echo "$path"
            target_space_bytes=$((target_space_bytes - size))
        fi
    done
}

parse_size_to_bytes() {
    local size_str="$1"
    local multiplier=1
    
    if [[ "$size_str" =~ ^([0-9.]+)(GB|MB|KB|G|M|K)?$ ]]; then
        local num="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]:-B}"
        
        case $unit in
            GB|G) multiplier=1073741824 ;;
            MB|M) multiplier=1048576 ;;
            KB|K) multiplier=1024 ;;
        esac
        
        echo "$num * $multiplier" | bc 2>/dev/null || echo "$num"
    else
        echo "0"
    fi
}

dry_run() {
    local days="$1"
    local target_space="$2"
    
    log "============================================================"
    log "              BACKUP CLEANUP (DRY RUN)                      "
    log "============================================================"
    log "Retention days: $days"
    [ -n "$target_space" ] && log "Target space to free: $target_space"
    log ""
    
    local total_freed=0
    local count=0
    
    # Find backups older than retention
    if [ -n "$days" ] && [ "$days" -gt 0 ]; then
        log "Backups older than $days days:"
        echo ""
        
        while IFS= read -r backup; do
            if [ -d "$backup" ]; then
                local name
                local size
                local age
                name=$(basename "$backup")
                size=$(du -sb "$backup" 2>/dev/null | cut -f1)
                age=$(get_backup_age "$backup")
                
                echo -e "  ${YELLOW}Would delete:${NC} $name"
                echo -e "    Size: $(format_size "$size")"
                echo -e "    Age: $age days"
                echo ""
                
                total_freed=$((total_freed + size))
                count=$((count + 1))
            fi
        done < <(find_old_backups "$days")
    fi
    
    # Find backups to free space
    if [ -n "$target_space" ]; then
        local target_bytes
        target_bytes=$(parse_size_to_bytes "$target_space")
        log "Backups to delete to free ${target_space}:"
        echo ""
        
        while IFS= read -r backup; do
            if [ -d "$backup" ]; then
                local name
                local size
                local age
                name=$(basename "$backup")
                size=$(du -sb "$backup" 2>/dev/null | cut -f1)
                age=$(get_backup_age "$backup")
                
                echo -e "  ${YELLOW}Would delete:${NC} $name"
                echo -e "    Size: $(format_size "$size")"
                echo -e "    Age: $age days"
                echo ""
                
                total_freed=$((total_freed + size))
                count=$((count + 1))
            fi
        done < <(find_large_backups "$target_bytes")
    fi
    
    echo "------------------------------------------------------------"
    log "Would delete: $count backup(s)"
    log "Would free: $(format_size $total_freed)"
    echo ""
}

cleanup() {
    local days="$1"
    local target_space="$2"
    local force="$3"
    
    local total_freed=0
    local count=0
    local deleted=()
    
    # Delete backups older than retention
    if [ -n "$days" ] && [ "$days" -gt 0 ]; then
        while IFS= read -r backup; do
            if [ -d "$backup" ]; then
                local name
                local size
                name=$(basename "$backup")
                size=$(du -sb "$backup" 2>/dev/null | cut -f1)
                
                if [ "$force" = true ]; then
                    rm -rf "$backup"
                fi
                
                total_freed=$((total_freed + size))
                count=$((count + 1))
                deleted+=("$name (${size})")
            fi
        done < <(find_old_backups "$days")
    fi
    
    # Delete backups to free space
    if [ -n "$target_space" ]; then
        local target_bytes
        target_bytes=$(parse_size_to_bytes "$target_space")
        
        while IFS= read -r backup; do
            if [ -d "$backup" ]; then
                local name
                local size
                name=$(basename "$backup")
                size=$(du -sb "$backup" 2>/dev/null | cut -f1)
                
                if [ "$force" = true ]; then
                    rm -rf "$backup"
                fi
                
                total_freed=$((total_freed + size))
                count=$((count + 1))
                deleted+=("$name (${size})")
            fi
        done < <(find_large_backups "$target_bytes")
    fi
    
    if [ "$force" = true ]; then
        log "============================================================"
        log "              BACKUP CLEANUP COMPLETE                      "
        log "============================================================"
        log "Deleted: $count backup(s)"
        log "Freed: $(format_size $total_freed)"
        echo ""
        
        if [ ${#deleted[@]} -gt 0 ]; then
            log "Deleted backups:"
            for item in "${deleted[@]}"; do
                echo "  - $item"
            done
        fi
        echo ""
    fi
}

confirm_cleanup() {
    echo ""
    log_warning "============================================================"
    log_warning "                    WARNING!                              "
    log_warning "============================================================"
    log_warning "This will permanently delete old backups."
    log_warning ""
    log_warning "Retention: $RETENTION_DAYS days"
    echo ""
    
    read -r -p "Type 'yes' to continue: " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Cleanup cancelled"
        exit 0
    fi
}

main() {
    local days="$RETENTION_DAYS"
    local target_space=""
    local dry_run_mode=false
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --days|-d)
                days="$2"
                shift 2
                ;;
            --space|-s)
                target_space="$2"
                shift 2
                ;;
            --dry-run)
                dry_run_mode=true
                shift
                ;;
            --force|-f)
                force=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --days N, -d N       Keep backups for N days (default: $RETENTION_DAYS)"
                echo "  --space SIZE, -s SIZE  Delete to free SIZE (e.g., 5GB, 1GB)"
                echo "  --dry-run            Show what would be deleted"
                echo "  --force, -f          Skip confirmation"
                echo "  --help, -h           Show this help"
                echo ""
                echo "Examples:"
                echo "  $0                    # Delete backups older than 90 days"
                echo "  $0 --days 30          # Delete backups older than 30 days"
                echo "  $0 --space 5GB        # Delete oldest backups until 5GB freed"
                echo "  $0 --dry-run --days 60 # Preview deletion"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_error "Backup directory not found: $BACKUP_DIR"
        exit 1
    fi
    
    if [ "$dry_run_mode" = true ]; then
        dry_run "$days" "$target_space"
    else
        if [ "$force" != true ]; then
            confirm_cleanup
        fi
        cleanup "$days" "$target_space" true
    fi
}

main "$@"
