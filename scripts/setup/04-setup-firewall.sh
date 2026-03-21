#!/bin/bash
# =============================================================================
# Paperclip Setup Script 04 - Firewall Setup
# =============================================================================
# This script configures UFW firewall for VPN-only access
# RUN AS: sudo bash 04-setup-firewall.sh
# =============================================================================

set -e

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║             Настройка Firewall (UFW)                         ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Запустите этот скрипт с sudo"
    echo "Usage: sudo bash $0"
    exit 1
fi

echo "[1/8] Проверка SSH..."
if dpkg -l | grep -q openssh-server; then
    echo "  SSH найден - разрешаем порт 22"
else
    echo "  SSH не установлен - добавляем правило на всякий случай"
fi

echo "[2/8] Установка UFW..."
apt install -y ufw

echo "[3/8] Сброс правил..."
ufw --force reset

echo "[4/8] Установка политик по умолчанию..."
ufw default deny incoming
ufw default allow outgoing
echo "  ✓ Входящие запрещены по умолчанию"
echo "  ✓ Исходящие разрешены по умолчанию"

echo "[5/8] Добавление правил..."
# SSH (всегда важно!)
ufw allow 22/tcp comment 'SSH'

# Tailscale VPN
ufw allow from 100.64.0.0/10 to any comment 'Tailscale VPN'
echo "  ✓ SSH (порт 22) - разрешён"
echo "  ✓ Tailscale VPN (100.64.0.0/10) - разрешён"

# Loopback
ufw allow in on lo
ufw allow out on lo
echo "  ✓ Loopback - разрешён"

echo "[6/8] Применение правил..."
echo ""
echo "─────────────────────────────────────────────────────────────────"
echo "ВНИМАНИЕ: UFW будет активирован!"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "Убедитесь, что:"
echo "  1. Вы подключены по SSH (порт 22)"
echo "  2. Или вы физически за компьютером"
echo ""
read -p "Нажмите Enter для продолжения..."

# Отключаем ufw перед включением (может заблокировать SSH)
ufw disable
echo "y" | ufw enable

echo "[7/8] Проверка статуса..."
ufw status verbose

echo "[8/8] Сохранение правил..."
ufw status > /opt/paperclip/.ufw-rules.txt 2>/dev/null || true

echo ""
echo "─────────────────────────────────────────────────────────────────"
echo "FIREWALL НАСТРОЕН!"
echo "─────────────────────────────────────────────────────────────────"
echo ""
echo "РАЗРЕШЁННЫЕ ПОДКЛЮЧЕНИЯ:"
echo "  • SSH (порт 22)"
echo "  • Tailscale VPN (100.64.0.0/10)"
echo ""
echo "ЗАБЛОКИРОВАННЫЕ ПОДКЛЮЧЕНИЯ:"
echo "  • Все входящие из интернета (порты 80, 443 и др.)"
echo ""
echo "ПОЛЕЗНЫЕ КОМАНДЫ:"
echo "  ufw status          - показать статус"
echo "  ufw allow 80/tcp    - разрешить порт"
echo "  ufw delete allow 22 - удалить правило"
echo "  ufw disable         - отключить firewall"
echo ""

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║               Firewall настроен!                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
