#!/bin/bash
# =============================================================================
# Paperclip Setup Script 03 - Create Directories
# =============================================================================
# This script creates necessary directories with proper permissions
# RUN AS: sudo bash 03-create-dirs.sh
# =============================================================================

set -e

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              Создание директорий                             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Запустите этот скрипт с sudo"
    echo "Usage: sudo bash $0"
    exit 1
fi

# Определение пользователя
CURRENT_USER=${SUDO_USER:-$(whoami)}
PAPERCLIP_HOME="/opt/paperclip"

echo "[1/6] Создание основной директории..."
mkdir -p "$PAPERCLIP_HOME"
mkdir -p "$PAPERCLIP_HOME/data"
mkdir -p "$PAPERCLIP_HOME/postgres"
mkdir -p "$PAPERCLIP_HOME/logs"
mkdir -p "$PAPERCLIP_HOME/certs"

echo "[2/6] Создание директорий для volumes..."
mkdir -p /var/lib/postgresql/paperclip
mkdir -p /var/lib/redis

echo "[3/6] Назначение прав на директории..."
# Основные директории
chown -R root:docker "$PAPERCLIP_HOME"
chmod -R 755 "$PAPERCLIP_HOME"

# Data директории (для Paperclip - UID 1000)
chown -R 1000:1000 "$PAPERCLIP_HOME/data"
chown -R 1000:1000 "$PAPERCLIP_HOME/logs"
chown -R 1000:1000 "$PAPERCLIP_HOME/certs"

# PostgreSQL директории (UID 999)
chown -R 999:999 /var/lib/postgresql/paperclip
chmod -R 700 /var/lib/postgresql/paperclip

# Redis директории (UID 999)
chown -R 999:999 /var/lib/redis
chmod -R 700 /var/lib/redis

echo "[4/6] Назначение прав текущему пользователю..."
# Добавить пользователя в группу docker для доступа к сокету
usermod -aG docker "$CURRENT_USER" 2>/dev/null || true
# Дать пользователю доступ к основной директории
chown -R "$CURRENT_USER:$CURRENT_USER" "$PAPERCLIP_HOME"

echo "[5/6] Создание README в директориях..."
echo "# Paperclip Data Directory" > "$PAPERCLIP_HOME/data/README.md"
echo "# Paperclip Postgres Directory" > "$PAPERCLIP_HOME/postgres/README.md"
echo "# Paperclip Logs Directory" > "$PAPERCLIP_HOME/logs/README.md"
echo "# Paperclip Certs Directory" > "$PAPERCLIP_HOME/certs/README.md"

echo "[6/6] Проверка..."
ls -la "$PAPERCLIP_HOME"

echo ""
echo "─────────────────────────────────────────────────────────────────"
echo "СТРУКТУРА СОЗДАННЫХ ДИРЕКТОРИЙ:"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "$PAPERCLIP_HOME/"
echo "├── data/       (UID 1000 - Paperclip)"
echo "├── postgres/   (UID 999 - PostgreSQL)"
echo "├── logs/       (UID 1000 - Logs)"
echo "├── certs/      (UID 1000 - TLS certificates)"
echo "└── .env        (создайте вручную)"
echo ""
echo "/var/lib/postgresql/paperclip (UID 999 - PostgreSQL data)"
echo "/var/lib/redis               (UID 999 - Redis data)"
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║               Директории созданы!                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
