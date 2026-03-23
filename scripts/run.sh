#!/bin/bash
# =============================================================================
# Paperclip - Main Run Script
# =============================================================================
# This script starts Paperclip with Docker Compose
# RUN AS: ./run.sh (без sudo)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                  Запуск Paperclip                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Проверка секретов
if [ ! -d "$PROJECT_ROOT/.secrets" ]; then
    echo "ERROR: Директория .secrets не найдена!"
    echo ""
    echo "Запустите скрипт генерации секретов:"
    echo "  ./scripts/generate-secrets.sh"
    echo ""
    exit 1
fi

# Проверка Docker
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker не запущен или нет прав доступа"
    echo ""
    echo "Запустите Docker:"
    echo "  sudo systemctl start docker"
    echo ""
    exit 1
fi

# Проверка секретов
echo "[1/5] Проверка конфигурации..."

if [ ! -f "$PROJECT_ROOT/.secrets/POSTGRES_PASSWORD" ]; then
    echo "ERROR: POSTGRES_PASSWORD не найден!"
    echo "Запустите ./scripts/generate-secrets.sh"
    exit 1
fi

if [ ! -f "$PROJECT_ROOT/.secrets/BETTER_AUTH_SECRET" ]; then
    echo "ERROR: BETTER_AUTH_SECRET не найден!"
    echo "Запустите ./scripts/generate-secrets.sh"
    exit 1
fi

echo "  ✓ Конфигурация проверена"

echo "[2/5] Проверка директорий..."
for dir in "$PAPERCLIP_DATA_DIR" "$POSTGRES_DATA_DIR"; do
    if [ -n "$dir" ] && [ -d "$dir" ]; then
        echo "  ✓ $dir"
    fi
done

echo "[3/5] Проверка сети..."

echo "[4/5] Запуск контейнеров..."
docker compose up -d

echo "[5/5] Ожидание запуска..."
echo "  Ждём 15 секунд для инициализации..."
sleep 15

echo ""
echo "─────────────────────────────────────────────────────────────────"
echo "СТАТУС КОНТЕЙНЕРОВ:"
echo "─────────────────────────────────────────────────────────────────"
docker compose ps

echo ""
echo "─────────────────────────────────────────────────────────────────"
echo "HEALTH CHECK:"
echo "─────────────────────────────────────────────────────────────────"
if curl -sf http://localhost:3100/health > /dev/null 2>&1; then
    echo "  ✓ Paperclip: OK"
else
    echo "  ⚠ Paperclip: Запускается..."
    echo "  Подождите ещё и проверьте: docker compose logs paperclip"
fi

if curl -sf http://localhost:5432 > /dev/null 2>&1; then
    echo "  ✓ PostgreSQL: OK"
else
    echo "  ⚠ PostgreSQL: Запускается..."
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                Paperclip запущен!                           ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "ДОСТУП:"
echo "  Локально:     http://localhost:3100"
echo "  OpenCode:     http://localhost:4096"
echo ""
echo "ЛОГИ:"
echo "  docker compose logs -f"
echo ""
echo "ОСТАНОВКА:"
echo "  docker compose down"
echo ""
