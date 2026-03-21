#!/bin/bash
# =============================================================================
# Paperclip - Main Run Script
# =============================================================================
# This script starts Paperclip with Docker Compose
# RUN AS: ./run.sh (без sudo)
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                  Запуск Paperclip                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Проверка .env файла
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "ERROR: .env файл не найден!"
    echo ""
    echo "Скопируйте пример и заполните:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    echo ""
    echo "НЕОБХОДИМЫЕ ПЕРЕМЕННЫЕ:"
    echo "  - POSTGRES_PASSWORD"
    echo "  - BETTER_AUTH_SECRET"
    echo "  - OPENAI_API_KEY"
    echo "  - ANTHROPIC_API_KEY"
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

# Проверка .env
echo "[1/5] Проверка конфигурации..."
source "$SCRIPT_DIR/.env" 2>/dev/null || true

if [ -z "$POSTGRES_PASSWORD" ] || [ "$POSTGRES_PASSWORD" = "<СГЕНЕРИРУЙТЕ>" ]; then
    echo "ERROR: POSTGRES_PASSWORD не настроен!"
    echo "Отредактируйте .env файл"
    exit 1
fi

if [ -z "$BETTER_AUTH_SECRET" ] || [ "$BETTER_AUTH_SECRET" = "<СГЕНЕРИРУЙТЕ>" ]; then
    echo "ERROR: BETTER_AUTH_SECRET не настроен!"
    echo "Отредактируйте .env файл"
    exit 1
fi

echo "  ✓ Конфигурация проверена"

echo "[2/5] Проверка директорий..."
for dir in "$PAPERCLIP_DATA_DIR" "$POSTGRES_DATA_DIR"; do
    if [ -n "$dir" ] && [ -d "$dir" ]; then
        echo "  ✓ $dir"
    fi
done

echo "[3/5] Создание Docker сети..."
docker network create paperclip-backend 2>/dev/null || true
echo "  ✓ Сеть paperclip-backend готова"

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
echo "  В Tailscale:  https://$(cat /opt/paperclip/.tailscale-hostname 2>/dev/null || echo 'paperclip').tailnet"
echo ""
echo "ЛОГИ:"
echo "  docker compose logs -f"
echo ""
echo "ОСТАНОВКА:"
echo "  docker compose down"
echo ""
