#!/bin/bash
# =============================================================================
# Paperclip Setup Script 02 - Install Tailscale
# =============================================================================
# This script installs and configures Tailscale VPN
# RUN AS: sudo bash 02-install-tailscale.sh
# =============================================================================

set -e

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                  Установка Tailscale                         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Запустите этот скрипт с sudo"
    echo "Usage: sudo bash $0"
    exit 1
fi

echo "[1/5] Установка Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo "[2/5] Проверка установки..."
tailscale version

echo "[3/5] Запуск авторизации..."
echo ""
echo "─────────────────────────────────────────────────────────────────"
echo "СЛЕДУЮЩИЙ ШАГ ВАЖЕН!"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "Откроется браузер для авторизации в Tailscale."
echo "После авторизации скопируйте auth-key из панели администратора:"
echo "  https://login.tailscale.com/admin/settings/keys"
echo ""
echo "Или используйте команду:"
echo "  tailscale up --accept-routes"
echo ""
read -p "Нажмите Enter когда авторизуетесь в Tailscale..."

echo "[4/5] Подключение к Tailscale..."
tailscale up --accept-routes

echo "[5/5] Получение информации..."
echo ""
TAILSCALE_HOSTNAME=$(tailscale status --self | jq -r '.HostName' 2>/dev/null || tailscale status | head -1 | awk '{print $1}')
TAILSCALE_IP=$(tailscale status --self | jq -r '.TailNetIPs[0]' 2>/dev/null || echo "unknown")

echo "─────────────────────────────────────────────────────────────────"
echo "TAILSCALE ПОДКЛЮЧЁН!"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "  Имя хоста: $TAILSCALE_HOSTNAME"
echo "  Tailscale IP: $TAILSCALE_IP"
echo "  HTTPS адрес: https://$TAILSCALE_HOSTNAME.tailnet"
echo ""
echo "СОХРАНИТЕ ЭТУ ИНФОРМАЦИЮ - она нужна для .env файла!"
echo ""

# Сохранение hostname для использования в других скриптах
if [ -d "/opt/paperclip" ]; then
    echo "$TAILSCALE_HOSTNAME" > /opt/paperclip/.tailscale-hostname
    echo "$TAILSCALE_IP" > /opt/paperclip/.tailscale-ip
fi

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              Tailscale настроен!                             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
