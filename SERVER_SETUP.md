# =============================================================================
# Paperclip Server Setup Guide - Home Server Edition
# =============================================================================
# 
# This guide helps you set up Paperclip on a home server with:
#   - 3GB RAM / 2 CPU cores
#   - Docker + Docker Compose
#   - Tailscale VPN for secure access
#   - UFW firewall (VPN-only access)
#
# =============================================================================

## 🎯 ОБЗОР СИСТЕМЫ

```
┌─────────────────────────────────────────────────────────────────┐
│                    YOUR HOME NETWORK                              │
│                                                                  │
│   ┌──────────────────┐         ┌─────────────────────────┐     │
│   │   Home Server    │         │   Your Computer        │     │
│   │                  │         │                        │     │
│   │  ┌────────────┐  │         │  ┌─────────────────┐  │     │
│   │  │ Paperclip  │  │  ←────  │  │   Browser       │  │     │
│   │  │ Container  │  │         │  └─────────────────┘  │     │
│   │  └────────────┘  │         └─────────────────────────┘     │
│   │        ↑         │                   ↑                      │
│   │        │         │                   │                      │
│   │  ┌────────────┐  │                   │                      │
│   │  │ PostgreSQL │  │                   │                      │
│   │  │ Container  │  │                   │                      │
│   │  └────────────┘  │                   │                      │
│   │        ↑         │                   │                      │
│   │        │         │         ┌──────────┴──────────┐         │
│   │  ┌────────────┐  │         │   Tailscale VPN    │         │
│   │  │   Redis    │  │         │   (Encrypted)      │         │
│   │  │ Container  │  │         └────────────────────┘         │
│   │  └────────────┘  │                                          │
│   │        ↑         │                                          │
│   │  ┌────────────┐  │                                          │
│   │  │  Traefik   │  │                                          │
│   │  │   Proxy    │  │                                          │
│   │  └────────────┘  │                                          │
│   │                  │                                          │
│   │   192.168.0.186  │                                          │
│   └──────────────────┘                                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📋 ТРЕБОВАНИЯ К СИСТЕМЕ

| Компонент | Минимум | Рекомендуется |
|----------|---------|----------------|
| RAM | 3 GB | 4+ GB |
| CPU | 2 cores | 4+ cores |
| Disk | 20 GB | 50+ GB SSD |
| OS | Ubuntu 22.04+ | Ubuntu 24.04 LTS |
| Network | Internet | Fiber/Cable |

---

## 🚀 БЫСТРЫЙ СТАРТ

### 1. Установка (выполните на сервере)

```bash
# Клонирование репозитория
cd /opt
git clone https://github.com/ваш-репозиторий/paperclip.git
cd paperclip

# Установка Docker (sudo)
sudo ./scripts/setup/01-install-docker.sh

# Перелогиньтесь для применения группы docker
exit
ssh user@server
cd /opt/paperclip

# Установка Tailscale (sudo)
sudo ./scripts/setup/02-install-tailscale.sh

# Создание директорий (sudo)
sudo ./scripts/setup/03-create-dirs.sh

# Настройка firewall (sudo)
sudo ./scripts/setup/04-setup-firewall.sh
```

### 2. Генерация секретов (локально)

На **вашем локальном компьютере**:

```bash
# Пароль PostgreSQL
openssl rand -base64 24 | tr -dc 'A-Za-z0-9!@#$%' | head -c 32

# BETTER_AUTH_SECRET
openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 64
```

### 3. Конфигурация (на сервере)

```bash
cd /opt/paperclip
cp scripts/.env .env
nano .env
```

Заполните `.env`:
```bash
POSTGRES_PASSWORD=ваш_сгенерированный_пароль
BETTER_AUTH_SECRET=ваш_сгенерированный_секрет
OPENAI_API_KEY=sk-...        # с platform.openai.com
ANTHROPIC_API_KEY=sk-ant-... # с console.anthropic.com
```

### 4. Запуск

```bash
# Загрузка образов
./scripts/setup/05-pull-images.sh

# Запуск
./scripts/run.sh
```

### 5. Доступ

Откройте в браузере:
- **Через Tailscale**: `https://paperclip.tailnet`
- **Локально**: `http://localhost:3100`

---

## 🔐 БЕЗОПАСНОСТЬ

### Что защищено:

| Защита | Описание |
|--------|---------|
| Non-root containers | Контейнеры запускаются от непривилегированных пользователей |
| Read-only filesystem | Файловая система контейнеров только для чтения |
| Firewall (UFW) | Закрыт доступ из интернета, открыт только VPN |
| Tailscale VPN | Зашифрованное соединение через VPN |
| TLS | Все соединения шифруются |
| Secrets | Пароли и ключи не хранятся в git |

### Firewall правила:

```
┌────────────────────────────────────────────────────────┐
│                   INCOMING TRAFFIC                      │
├────────────────────────────────────────────────────────┤
│  SSH (22)          ✓ ALLOWED  - Server management    │
│  Tailscale VPN     ✓ ALLOWED  - Access to Paperclip   │
│  HTTP/HTTPS        ✗ BLOCKED  - No public access    │
│  Everything else   ✗ BLOCKED  - Default deny        │
└────────────────────────────────────────────────────────┘
```

---

## 📊 РЕСУРСЫ

### Распределение памяти (3GB):

| Сервис | RAM | Notes |
|--------|-----|-------|
| Paperclip | 1 GB | Основное приложение |
| PostgreSQL | 1 GB | База данных |
| Redis | 128 MB | Кэширование |
| Traefik | 128 MB | Reverse proxy |
| **System reserve** | 744 MB | Buffer |
| **Total** | 3 GB | |

### CPU:

| Сервис | CPU |
|--------|-----|
| Paperclip | 1 core |
| PostgreSQL | 0.5 cores |
| Redis | 0.25 cores |
| Traefik | 0.25 cores |
| **Total** | 2 cores |

---

## 🔧 ОБСЛУЖИВАНИЕ

### Мониторинг:

```bash
# Статус контейнеров
docker compose ps

# Использование ресурсов
docker stats

# Логи в реальном времени
docker compose logs -f

# Логи конкретного сервиса
docker compose logs -f paperclip
```

### Обновление:

```bash
# Остановить
docker compose down

# Обновить код
git pull

# Пересобрать и запустить
docker compose build
docker compose up -d
```

### Резервное копирование:

```bash
# Бэкап базы данных
docker compose exec -T db pg_dump -U paperclip > backup_$(date +%Y%m%d).sql

# Бэкап данных
tar -czf paperclip-data_$(date +%Y%m%d).tar.gz data/
```

### Восстановление:

```bash
# Восстановление базы данных
cat backup_20240101.sql | docker compose exec -T db psql -U paperclip
```

---

## ❓ FAQ

**Q: Paperclip не запускается**
```
Проверьте логи: docker compose logs paperclip
```

**Q: Нет доступа к Tailscale**
```
Проверьте: tailscale status
Подключитесь: tailscale up
```

**Q: Ошибка подключения к БД**
```
Проверьте: docker compose logs db
Перезапустите: docker compose restart db
```

**Q: Мало памяти**
```
Увеличьте RAM сервера или уменьшите лимиты в docker-compose.yml
```

---

## 📞 КОНТАКТЫ

При проблемах создайте issue в репозитории или обратитесь к документации.
