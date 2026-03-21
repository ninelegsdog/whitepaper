#!/bin/bash
# =============================================================================
# Paperclip Setup Script 01 - Install Docker
# =============================================================================
# This script installs Docker Engine and Docker Compose
# RUN AS: sudo bash 01-install-docker.sh
# =============================================================================

set -e

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           Установка Docker и Docker Compose                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Запустите этот скрипт с sudo"
    echo "Usage: sudo bash $0"
    exit 1
fi

echo "[1/7] Обновление системы..."
apt update && apt upgrade -y

echo "[2/7] Установка зависимостей..."
apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    jq

echo "[3/7] Добавление GPG ключа Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
chmod a+r /etc/apt/keyrings/docker.gpg

echo "[4/7] Добавление репозитория Docker..."
ARCH=$(dpkg --print-architecture)
DISTRO=$(lsb_release -cs 2>/dev/null || echo "jammy")
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $DISTRO stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[5/7] Установка Docker Engine..."
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "[6/7] Включение Docker..."
systemctl enable docker
systemctl start docker

echo "[7/7] Настройка пользователя..."
CURRENT_USER=${SUDO_USER:-$(whoami)}
usermod -aG docker "$CURRENT_USER"
echo "Пользователь $CURRENT_USER добавлен в группу docker"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                   Docker установлен!                          ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "ВЫЙДИТЕ И ВОЙДИТЕ СНОВА в систему для применения группы docker"
echo ""
echo "Проверка:"
echo "  docker --version"
echo "  docker compose version"
echo ""
