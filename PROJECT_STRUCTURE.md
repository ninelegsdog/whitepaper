# Структура проекта Paperclip

Краткое руководство по назначению каждого файла и каталога.

---

## Основные Docker файлы

| Файл | Назначение | Примеры команд |
|-------|------------|----------------|
| **docker-compose.yml** | Главный стек: Paperclip + PostgreSQL + Redis + OpenCode | `docker compose up -d` |
| **docker-compose.monitoring.yml** | Мониторинг: Prometheus + Grafana + Loki + Alertmanager | `docker compose -f docker-compose.yml -f docker-compose.monitoring.yml --profile monitoring up -d` |
| **docker-compose.dev.yml** | Разработка: hot-reload, отладка | `docker compose -f docker-compose.dev.yml up -d` |
| **docker-compose.ci.yml** | CI/CD тесты (GitHub Actions) | Автоматически |

---

## Docker образы

| Файл | Назначение |
|------|------------|
| **Dockerfile** | Образ Paperclip для production |
| **Dockerfile.dev** | Образ для разработки (с исходниками) |
| **Dockerfile.ci** | Образ для CI/CD тестов |
| **opencode/Dockerfile.opencode** | Образ OpenCode AI агента |

---

## Управление

| Файл | Назначение | Примеры команд |
|-------|------------|----------------|
| **Makefile** | Команды управления | `make up`, `make down`, `make logs`, `make backup`, `make validate` |
| **.env.example** | Шаблон переменных окружения | `cp .env.example .env` |
| **.gitignore** | Файлы недоступные git (секреты, данные) | — |

---

## OpenCode (AI агент)

| Файл | Назначение |
|------|------------|
| **opencode/opencode-config.json** | Конфиг провайдеров (Groq) и модели |
| **opencode/config.json** | Копия конфига для Docker образа |

---

## Скрипты управления

### Бэкап система

| Файл | Назначение | Команда |
|------|------------|---------|
| **scripts/backup/backup.sh** | Полный бэкап (БД, Redis, данные, конфиги) | `make backup` |
| **scripts/backup/restore.sh** | Восстановление из бэкапа | `make restore BACKUP=backup-20260322-030000` |
| **scripts/backup/list-backups.sh** | Список всех бэкапов | `make list-backups` |
| **scripts/backup/cleanup.sh** | Очистка старых бэкапов (>90 дней) | `make cleanup` |

### Установка сервера (sudo)

| Файл | Назначение | Команда |
|------|------------|---------|
| **scripts/setup/01-install-docker.sh** | Docker + Docker Compose | `sudo ./01-install-docker.sh` |
| **scripts/setup/02-install-tailscale.sh** | VPN для безопасного доступа | `sudo ./02-install-tailscale.sh` |
| **scripts/setup/03-create-dirs.sh** | Создание директорий | `sudo ./03-create-dirs.sh` |
| **scripts/setup/04-setup-firewall.sh** | Firewall UFW | `sudo ./04-setup-firewall.sh` |
| **scripts/setup/05-pull-images.sh** | Загрузка Docker образов | `sudo ./05-pull-images.sh` |

### Общие скрипты

| Файл | Назначение | Команда |
|------|------------|---------|
| **scripts/validate.sh** | Проверка конфигурации перед запуском | `make validate` |
| **scripts/healthcheck.sh** | Проверка здоровья сервисов | `make health` |
| **scripts/run.sh** | Запуск приложения | `./run.sh` |
| **scripts/generate-secrets.sh** | Генерация паролей | `./generate-secrets.sh` |

---

## Мониторинг

| Файл | Назначение |
|------|------------|
| **prometheus.yml** | Prometheus targets, scrape intervals |
| **alert.rules.yml** | Правила алертов |
| **alertmanager.yml** | Куда отправлять уведомления о проблемах |
| **loki-config.yml** | Loki — хранение логов |
| **promtail-config.yml** | Promtail — отправка логов в Loki |

### Grafana provisioning (автоматическая настройка)

| Файл | Назначение |
|------|------------|
| **grafana/provisioning/datasources/prometheus.yml** | Prometheus и Loki datasources |
| **grafana/provisioning/dashboards/** | Дашборды мониторинга |

---

## Документация

| Файл | Назначение |
|------|------------|
| **README.md** | Быстрый старт, основные команды |
| **DOCKER.md** | Подробная Docker документация (EN) |
| **SERVER_SETUP.md** | Установка на сервер с нуля (RU) |
| **AGENTS.md** | Инструкции для AI-агентов |
| **LICENSE** | Лицензия MIT |

---

## Директории данных

Эти директории создаются автоматически и **не попадают в git**:

| Директория | Назначение |
|------------|------------|
| **data/** | Данные приложения, файлы PostgreSQL, Paperclip |
| **logs/** | Логи приложения |
| **backups/** | Резервные копии |
| **.secrets/** | Секреты для генерации паролей |

---

## GitHub Actions (CI/CD)

| Директория/Файл | Назначение |
|-----------------|------------|
| **.github/workflows/docker-test.yml** | Автоматические тесты и проверки |

---

## Быстрый старт

```bash
# 1. Клонировать и настроить
git clone https://github.com/ninelegsdog/whitepaper.git
cd whitepaper
cp .env.example .env

# 2. Заполнить .env (GROQ_API_KEY, OPENCODE_API_PASSWORD)

# 3. Запустить
make up

# 4. Или классически
docker compose up -d

# Проверить статус
make status

# Создать бэкап
make backup

# Посмотреть логи
make logs
```

---

## endpoints

| Сервис | Порт | URL |
|--------|------|-----|
| Paperclip | 3100 | http://localhost:3100 |
| OpenCode | 4096 | http://localhost:4096 |
| Prometheus | 9090 | http://localhost:9090 (localhost only) |
| Grafana | 3000 | http://localhost:3000 (localhost only) |
| Alertmanager | 9093 | http://localhost:9093 (localhost only) |
