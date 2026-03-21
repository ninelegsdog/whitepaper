#!/bin/bash
# =============================================================================
# Paperclip Setup Script 05 - Pull Docker Images
# =============================================================================
# This script downloads Docker images for Paperclip
# RUN AS: bash 05-pull-images.sh (без sudo)
# =============================================================================

set -e

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║            Загрузка Docker образов                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Проверка Docker
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker не запущен или нет прав доступа"
    echo ""
    echo "Проверьте:"
    echo "  1. Docker установлен:    docker --version"
    echo "  2. Docker запущен:     sudo systemctl start docker"
    echo "  3. Группа docker:      groups | grep docker"
    echo "  4. Перелогиньтесь после добавления в группу docker"
    exit 1
fi

echo "[1/5] Загрузка Traefik..."
docker pull traefik:v3.0

echo "[2/5] Загрузка PostgreSQL..."
docker pull postgres:17-alpine

echo "[3/5] Загрузка Redis..."
docker pull redis:7-alpine

echo "[4/5] Проверка загруженных образов..."
docker images | grep -E "traefik|postgres|redis|paperclip"

echo "[5/5] Очистка неиспользуемых образов..."
docker image prune -f

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║            Образы загружены!                                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
