#!/bin/bash
# =============================================================================
# Paperclip List Backups Script
# =============================================================================
# Lists all available backups with details
# 
# Usage:
#   ./list-backups.sh
#   ./list-backups.sh --json    # JSON output
#   ./list-backups.sh --stats   # Show statistics
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-${PROJECT_ROOT}/backups}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

format_size() {
    local size=$1
    if [ $size -gt 1073741824 ]; then
        echo "$(echo "scale=2; $size/1073741824" | bc 2>/dev/null || echo "$((size / 1073741824))")GB"
    elif [ $size -gt 1048576 ]; then
        echo "$(echo "scale=2; $size/1048576" | bc 2>/dev/null || echo "$((size / 1048576))")MB"
    elif [ $size -gt 1024 ]; then
        echo "$((size / 1024))KB"
    else
        echo "${size}B"
    fi
}

list_backups() {
    local format="${1:-table}"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}No backups directory found${NC}"
        exit 0
    fi
    
    local backups=()
    local total_size=0
    local count=0
    
    for backup in "$BACKUP_DIR"/backup-*/; do
        if [ -d "$backup" ]; then
            backups+=("$(basename "$backup")")
            count=$((count + 1))
            total_size=$((total_size + $(du -sb "$backup" 2>/dev/null | cut -f1)))
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}No backups found${NC}"
        exit 0
    fi
    
    case $format in
        json)
            echo "{"
            echo "  \"total_backups\": $count,"
            echo "  \"total_size\": \"$(format_size $total_size)\","
            echo "  \"backup_dir\": \"$BACKUP_DIR\","
            echo "  \"backups\": ["
            
            local first=true
            for backup in "${backups[@]}"; do
                local backup_path="${BACKUP_DIR}/${backup}"
                local size=$(du -sb "$backup_path" 2>/dev/null | cut -f1)
                local date=$(stat -c %y "$backup_path" 2>/dev/null | cut -d' ' -f1)
                local time=$(stat -c %y "$backup_path" 2>/dev/null | cut -d' ' -f2 | cut -d'.' -f1)
                local age_days=$(($(date +%s) - $(stat -c %Y "$backup_path")))
                age_days=$((age_days / 86400))
                
                local has_db="false"
                local has_redis="false"
                local has_data="false"
                local has_configs="false"
                
                [ -f "${backup_path}/paperclip-db.sql.gz" ] && has_db="true"
                [ -f "${backup_path}/dump.rdb" ] && has_redis="true"
                [ -f "${backup_path}/paperclip-data.tar.gz" ] && has_data="true"
                [ -f "${backup_path}/configs.tar.gz" ] && has_configs="true"
                
                if [ "$first" = true ]; then
                    first=false
                else
                    echo ","
                fi
                
                cat << EOF
    {
      "name": "$backup",
      "date": "$date",
      "time": "$time",
      "size": "$(format_size $size)",
      "size_bytes": $size,
      "age_days": $age_days,
      "components": {
        "database": $has_db,
        "redis": $has_redis,
        "data": $has_data,
        "configs": $has_configs
      }
    }
EOF
            done
            
            echo ""
            echo "  ]"
            echo "}"
            ;;
        
        stats)
            echo ""
            echo -e "${BLUE}=== Backup Statistics ===${NC}"
            echo ""
            echo "  Total backups: $count"
            echo "  Total size:   $(format_size $total_size)"
            echo "  Average size:  $(format_size $((total_size / count)))"
            echo "  Backup dir:    $BACKUP_DIR"
            echo ""
            
            # Find oldest and newest
            local oldest="${backups[0]}"
            local newest="${backups[$((count - 1))]}"
            
            if [ -d "${BACKUP_DIR}/${oldest}" ]; then
                local oldest_date=$(stat -c %y "${BACKUP_DIR}/${oldest}" 2>/dev/null | cut -d' ' -f1)
                local oldest_age=$(($(date +%s) - $(stat -c %Y "${BACKUP_DIR}/${oldest}")))
                oldest_age=$((oldest_age / 86400))
                echo "  Oldest:        $oldest ($oldest_date, ${oldest_age} days ago)"
            fi
            
            if [ -d "${BACKUP_DIR}/${newest}" ]; then
                local newest_date=$(stat -c %y "${BACKUP_DIR}/${newest}" 2>/dev/null | cut -d' ' -f1)
                echo "  Newest:        $newest ($newest_date)"
            fi
            
            echo ""
            ;;
        
        *)
            echo ""
            echo -e "${BLUE}=== Available Backups ===${NC}"
            echo ""
            printf "%-30s %12s %12s %s\n" "BACKUP NAME" "SIZE" "AGE" "DATE"
            echo "------------------------------------------------------------"
            
            for backup in "${backups[@]}"; do
                local backup_path="${BACKUP_DIR}/${backup}"
                local size=$(du -sh "$backup_path" 2>/dev/null | cut -f1)
                local age_seconds=$(($(date +%s) - $(stat -c %Y "$backup_path" 2>/dev/null || echo "0")))
                local age_days=$((age_seconds / 86400))
                local age_str="${age_days}d"
                
                if [ $age_days -eq 0 ]; then
                    age_str="today"
                elif [ $age_days -eq 1 ]; then
                    age_str="1d"
                fi
                
                local date=$(stat -c %y "$backup_path" 2>/dev/null | cut -d' ' -f1)
                
                # Color age
                local age_color="$NC"
                if [ $age_days -lt 7 ]; then
                    age_color="$GREEN"
                elif [ $age_days -lt 30 ]; then
                    age_color="$BLUE"
                elif [ $age_days -lt 60 ]; then
                    age_color="$YELLOW"
                else
                    age_color="$RED"
                fi
                
                printf "%-30s %12s ${age_color}%12s${NC} %s\n" "$backup" "$size" "$age_str" "$date"
            done
            
            echo ""
            echo -e "${BLUE}=== Summary ===${NC}"
            echo "  Total: $count backups, $(format_size $total_size)"
            echo ""
            ;;
    esac
}

main() {
    local format="table"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --json|-j)
                format="json"
                shift
                ;;
            --stats|-s)
                format="stats"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --json, -j     Output as JSON"
                echo "  --stats, -s    Show statistics only"
                echo "  --help, -h    Show this help"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
    
    list_backups "$format"
}

main "$@"
