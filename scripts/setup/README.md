# =============================================================================
# Paperclip Setup Scripts - Home Server
# =============================================================================
# Automated installation scripts for Paperclip on home server
# 
# System Requirements:
#   - RAM: 3 GB
#   - CPU: 2 cores
#   - OS: Ubuntu 22.04+ / Debian 12+
#   - Network: Internet connection
# =============================================================================

## 📋 ПОРЯДОК УСТАНОВКИ

### ШАГ 1: На сервере (под root)

```bash
cd /opt/paperclip

# Установка Docker
sudo ./setup/01-install-docker.sh

# Выйти и войти снова в систему (для применения группы docker)
exit
ssh user@server
cd /opt/paperclip

# Создание директорий
sudo ./setup/03-create-dirs.sh

# Настройка firewall
sudo ./setup/04-setup-firewall.sh
```

### ШАГ 2: Локально - Генерация секретов

На **локальном компьютере**:

```bash
# Пароль PostgreSQL (32 символа)
openssl rand -base64 24 | tr -dc 'A-Za-z0-9!@#$%' | head -c 32
# Пример: Xk9mP2nL5qR8vW3jY7bH6dF4cK9

# BETTER_AUTH_SECRET (64 символа)
openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 64
# Пример: aB7cD9eF1gH3iJ5kL7mN9oP1qR3sT5uV7wX9yZ1aB3cD5eF7gH9iJ1kL3
```

### ШАГ 3: На сервере - Заполнение .env

```bash
cd /opt/paperclip
cp scripts/.env .env
nano .env
```

Заполните:
- `POSTGRES_PASSWORD` - ваш пароль из ШАГА 2
- `BETTER_AUTH_SECRET` - ваш секрет из ШАГА 2
- `OPENAI_API_KEY` - получите на platform.openai.com
- `ANTHROPIC_API_KEY` - получите на console.anthropic.com

### ШАГ 4: Запуск

```bash
# Загрузка Docker образов
./setup/05-pull-images.sh

# Запуск Paperclip
./run.sh
```

---

## 📁 СТРУКТУРА СКРИПТОВ

```
scripts/
├── setup/
│   ├── 01-install-docker.sh    # Установка Docker (sudo)
│   ├── 03-create-dirs.sh       # Создание директорий (sudo)
│   ├── 04-setup-firewall.sh    # Настройка UFW (sudo)
│   └── 05-pull-images.sh       # Загрузка образов
├── .env                        # Пример .env файла
└── run.sh                      # Основной скрипт запуска
```

---

## 🔐 БЕЗОПАСНОСТЬ

### Что делают скрипты:

| Скрипт | Действия |
|--------|----------|
| `01-install-docker.sh` | Установка Docker Engine, добавление пользователя в группу docker |
| `03-create-dirs.sh` | Создание директорий с правильными правами |
| `04-setup-firewall.sh` | UFW firewall: закрыт доступ извне, открыта локальная сеть |

### Firewall правила:

```
ВХОДЯЩИЕ:
  ✓ SSH (порт 2222)        - для управления
  ✓ Локальная сеть         - для доступа к Paperclip
  ✗ Всё остальное          - ЗАБЛОКИРОВАНО

ИСХОДЯЩИЕ:
  ✓ Всё разрешено
```

---

## 🌐 ДОСТУП К PAPERCLIP

После установки Paperclip будет доступен:

| Сервис | Адрес | Пользователь | Пароль |
|--------|-------|-------------|--------|
| Paperclip | http://192.168.0.186:3100 | admin | paperclip |
| OpenCode | http://192.168.0.186:4096 | admin | paperclip |

---

## 🔧 ПОЛЕЗНЫЕ КОМАНДЫ

```bash
# Статус контейнеров
docker compose ps

# Просмотр логов
docker compose logs -f

# Просмотр логов конкретного сервиса
docker compose logs -f paperclip
docker compose logs -f db

# Перезапуск
docker compose restart

# Остановка
docker compose down

# Обновление
git pull
docker compose build
docker compose up -d

# Проверка health
curl http://localhost:3100/health

# Мониторинг ресурсов
docker stats

# Очистка
docker system prune -a
```

---

## ❓ TROUBLESHOOTING

### Docker не запущен:
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### Нет прав доступа к Docker:
```bash
# Перелогиньтесь или выполните:
newgrp docker
```

### Paperclip не запускается:
```bash
docker compose logs paperclip
docker compose restart paperclip
```

### Проблемы с БД:
```bash
docker compose logs db
docker compose exec db pg_isready -U paperclip
```

---

## 📞 ПОДДЕРЖКА

При проблемах проверьте:
1. `docker compose logs` - логи всех сервисов
2. `docker stats` - использование ресурсов
3. `df -h` - свободное место на диске
4. `free -h` - использование RAM
