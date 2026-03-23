# =============================================================================
# Paperclip Makefile
# =============================================================================
# Convenience commands for Paperclip deployment
# 
# Usage:
#   make up              # Start all services
#   make down            # Stop all services
#   make logs            # View logs
#   make backup          # Create backup
#   make status          # Show service status
# =============================================================================

.PHONY: help up down restart logs logs-opencode logs-app logs-db logs-redis status
.PHONY: backup backup-db backup-redis list-backups restore
.PHONY: validate health clean prune ps nginx-up nginx-down

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# Docker compose files
COMPOSE_FILES := -f docker-compose.yml
MONITORING_FILES := -f docker-compose.monitoring.yml
DEV_FILES := -f docker-compose.dev.yml
NGINX_FILES := -f docker-compose.nginx.yml
ALL_FILES := $(COMPOSE_FILES) $(MONITORING_FILES)

# Directories
SCRIPT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
BACKUP_DIR := $(SCRIPT_DIR)/backups
LOG_DIR := $(SCRIPT_DIR)/logs
DATA_DIR := $(SCRIPT_DIR)/data

# Default target
help:
	@echo ""
	@echo "$(BLUE)=== Paperclip Makefile ===$(NC)"
	@echo ""
	@echo "$(GREEN)Main Commands:$(NC)"
	@echo "  make up              Start all services (paperclip, db, redis, opencode)"
	@echo "  make down            Stop all services"
	@echo "  make restart         Restart all services"
	@echo "  make logs           View all logs (follow mode)"
	@echo "  make status         Show service status"
	@echo ""
	@echo "$(GREEN)Service Logs:$(NC)"
	@echo "  make logs-opencode  View OpenCode logs"
	@echo "  make logs-app       View Paperclip app logs"
	@echo "  make logs-db        View PostgreSQL logs"
	@echo "  make logs-redis     View Redis logs"
	@echo ""
	@echo "$(GREEN)Backup & Restore:$(NC)"
	@echo "  make backup              Full backup (all data)"
	@echo "  make backup-db           Backup PostgreSQL only"
	@echo "  make backup-redis       Backup Redis only"
	@echo "  make list-backups        List all backups"
	@echo "  make restore <backup>    Restore from backup"
	@echo "  make cleanup             Clean old backups"
	@echo ""
	@echo "$(GREEN)Maintenance:$(NC)"
	@echo "  make validate    Validate configuration"
	@echo "  make health     Check service health"
	@echo "  make clean      Remove volumes (DANGEROUS)"
	@echo "  make prune      Clean unused Docker resources"
	@echo "  make ps         Show Docker containers"
	@echo ""
	@echo "$(GREEN)Monitoring:$(NC)"
	@echo "  make monitoring-up   Start monitoring stack"
	@echo "  make monitoring-down Stop monitoring stack"
	@echo ""
	@echo "$(GREEN)Nginx Proxy:$(NC)"
	@echo "  make nginx-up       Start Nginx reverse proxy"
	@echo "  make nginx-down      Stop Nginx reverse proxy"
	@echo ""
	@echo "$(GREEN)Development:$(NC)"
	@echo "  make dev         Start development environment"
	@echo "  make dev-logs    View development logs"
	@echo "  make dev-down    Stop development environment"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make up                      # Start everything"
	@echo "  make logs-opencode -f        # Follow OpenCode logs"
	@echo "  make backup                  # Create full backup"
	@echo "  make restore backup-20260322-030000  # Restore specific backup"
	@echo ""

# -----------------------------------------------------------------------------
# Main Commands
# -----------------------------------------------------------------------------

up: validate
	@mkdir -p $(BACKUP_DIR) $(LOG_DIR)
	@echo "$(GREEN)Starting Paperclip...$(NC)"
	docker compose $(COMPOSE_FILES) $(NGINX_FILES) up -d
	@echo ""
	@echo "$(GREEN)Services started!$(NC)"
	@echo "  Paperclip: http://192.168.0.186:3100"
	@echo "  OpenCode:  http://192.168.0.186:4096"
	@echo "  Auth:      admin / paperclip"
	@echo ""

down:
	@echo "$(YELLOW)Stopping Paperclip...$(NC)"
	docker compose $(ALL_FILES) $(NGINX_FILES) down
	@echo "$(GREEN)Services stopped$(NC)"

restart: down up
	@echo "$(GREEN)Services restarted$(NC)"

# -----------------------------------------------------------------------------
# Logs
# -----------------------------------------------------------------------------

logs:
	docker compose $(ALL_FILES) logs -f

logs-opencode:
	docker compose $(COMPOSE_FILES) logs -f paperclip-opencode

logs-app:
	docker compose $(COMPOSE_FILES) logs -f paperclip-app

logs-db:
	docker compose $(COMPOSE_FILES) logs -f paperclip-db

logs-redis:
	docker compose $(COMPOSE_FILES) logs -f paperclip-redis

# -----------------------------------------------------------------------------
# Status
# -----------------------------------------------------------------------------

status:
	@echo ""
	@echo "$(BLUE)=== Paperclip Status ===$(NC)"
	@echo ""
	@docker compose $(ALL_FILES) ps
	@echo ""

ps:
	@docker ps -a --filter "name=paperclip" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

health:
	@echo ""
	@echo "$(BLUE)=== Service Health ===$(NC)"
	@echo ""
	@docker compose $(COMPOSE_FILES) ps --format "json" | jq -r '. | "\(.Service): \(.Health // "N/A")"' 2>/dev/null || \
		docker compose $(COMPOSE_FILES) ps

# -----------------------------------------------------------------------------
# Backup & Restore
# -----------------------------------------------------------------------------

backup:
	@mkdir -p $(BACKUP_DIR)
	@echo "$(GREEN)Creating backup...$(NC)"
	@$(SCRIPT_DIR)/scripts/backup/backup.sh

backup-db:
	@mkdir -p $(BACKUP_DIR)
	@echo "$(GREEN)Backing up database...$(NC)"
	@$(SCRIPT_DIR)/scripts/backup/backup.sh --db-only

backup-redis:
	@mkdir -p $(BACKUP_DIR)
	@echo "$(GREEN)Backing up Redis...$(NC)"
	@$(SCRIPT_DIR)/scripts/backup/backup.sh --redis-only

list-backups:
	@$(SCRIPT_DIR)/scripts/backup/list-backups.sh

restore:
ifndef BACKUP
	@echo "$(RED)Error: BACKUP name required$(NC)"
	@echo "Usage: make restore BACKUP=backup-20260322-030000"
	@exit 1
endif
	@echo "$(YELLOW)Restoring from $(BACKUP)...$(NC)"
	@$(SCRIPT_DIR)/scripts/backup/restore.sh $(BACKUP)

cleanup:
	@$(SCRIPT_DIR)/scripts/backup/cleanup.sh

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

validate:
	@echo "$(BLUE)Validating configuration...$(NC)"
	@$(SCRIPT_DIR)/scripts/validate.sh
	@docker compose $(ALL_FILES) config --quiet && \
		echo "$(GREEN)Configuration valid!$(NC)" || \
		(echo "$(RED)Configuration error!$(NC)" && exit 1)

# -----------------------------------------------------------------------------
# Maintenance
# -----------------------------------------------------------------------------

clean:
	@echo "$(RED)!!! WARNING !!!$(NC)"
	@echo "$(RED)This will delete ALL volumes and data!$(NC)"
	@echo ""
	@read -p "Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		echo "$(YELLOW)Deleting volumes...$(NC)"; \
		docker compose $(ALL_FILES) down -v; \
		echo "$(GREEN)Volumes deleted$(NC)"; \
	else \
		echo "Cancelled"; \
	fi

prune:
	@echo "$(YELLOW)Cleaning unused Docker resources...$(NC)"
	docker system prune -f --volumes
	@echo "$(GREEN)Cleanup complete$(NC)"

# -----------------------------------------------------------------------------
# Monitoring
# -----------------------------------------------------------------------------

monitoring-up:
	@echo "$(GREEN)Starting monitoring stack...$(NC)"
	@mkdir -p $(BACKUP_DIR)
	docker compose $(ALL_FILES) --profile monitoring up -d
	@echo ""
	@echo "$(GREEN)Monitoring started!$(NC)"
	@echo "  Prometheus:    http://localhost:9090 (localhost only)"
	@echo "  Grafana:       http://localhost:3000 (localhost only)"
	@echo "  Alertmanager:  http://localhost:9093 (localhost only)"
	@echo ""

monitoring-down:
	@echo "$(YELLOW)Stopping monitoring stack...$(NC)"
	docker compose $(ALL_FILES) --profile monitoring down
	@echo "$(GREEN)Monitoring stopped$(NC)"

# -----------------------------------------------------------------------------
# Nginx Reverse Proxy
# -----------------------------------------------------------------------------

nginx-up:
	@echo "$(GREEN)Starting Nginx reverse proxy...$(NC)"
	docker compose $(COMPOSE_FILES) $(NGINX_FILES) up -d nginx
	@echo "$(GREEN)Nginx started!$(NC)"
	@echo "  Paperclip: http://192.168.0.186:3100"
	@echo "  OpenCode:  http://192.168.0.186:4096"
	@echo "  Auth:      admin / paperclip"
	@echo ""

nginx-down:
	@echo "$(YELLOW)Stopping Nginx...$(NC)"
	docker compose $(COMPOSE_FILES) $(NGINX_FILES) down nginx
	@echo "$(GREEN)Nginx stopped$(NC)"

# -----------------------------------------------------------------------------
# Development
# -----------------------------------------------------------------------------

dev:
	@echo "$(GREEN)Starting development environment...$(NC)"
	docker compose $(DEV_FILES) --profile development up -d
	@echo "$(GREEN)Development environment started!$(NC)"
	@echo "  Paperclip Dev: http://localhost:3100"

dev-logs:
	docker compose $(DEV_FILES) logs -f

dev-down:
	@echo "$(YELLOW)Stopping development environment...$(NC)"
	docker compose $(DEV_FILES) down
	@echo "$(GREEN)Development environment stopped$(NC)"

# -----------------------------------------------------------------------------
# Install/Uninstall (for system integration)
# -----------------------------------------------------------------------------

install:
	@echo "$(GREEN)Installing Paperclip...$(NC)"
	@mkdir -p $(BACKUP_DIR) $(LOG_DIR)
	@echo "$(GREEN)Directories created. Run 'cp .env.example .env' and edit .env$(NC)"

uninstall:
	@echo "$(RED)!!! WARNING !!!$(NC)"
	@echo "$(RED)This will remove all containers and data!$(NC)"
	@read -p "Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker compose $(ALL_FILES) down -v --rmi local; \
		echo "$(GREEN)Uninstall complete$(NC)"; \
	else \
		echo "Cancelled"; \
	fi
