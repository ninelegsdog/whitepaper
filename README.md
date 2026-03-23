# Paperclip Docker Configuration

Docker-конфигурация для развёртывания [Paperclip](https://github.com/paperclipai/paperclip) — платформы оркестрации AI-агентов на домашнем сервере.

## Особенности

- **Бесплатные AI модели** — Groq API (Llama 3.3 70B)
- **Локальная сеть** — доступ через Nginx reverse proxy
- **Basic Auth** — защита с логином/паролем
- **Минимальные требования** — 7GB RAM, 2+ CPU
- **Максимальная безопасность** — non-root контейнеры, read-only fs, dropped capabilities
- **Backup система** — автоматическое резервное копирование с ротацией
- **Logging limits** — ограничение размера логов

## Быстрый старт

```bash
# Клонирование
git clone https://github.com/ninelegsdog/whitepaper.git
cd whitepaper

# Проверка конфигурации
make validate

# Запуск
make up

# Или классический способ
cp .env.example .env
nano .env  # Заполните GROQ_API_KEY и OPENCODE_API_PASSWORD
docker compose up -d
```

## Makefile команды

```bash
# Основные команды
make up              # Запуск всех сервисов
make down            # Остановка всех сервисов
make restart         # Перезапуск
make logs            # Просмотр логов
make status          # Статус сервисов

# Backup & Restore
make backup              # Полный бэкап
make backup-db           # Бэкап только БД
make list-backups        # Список бэкапов
make restore BACKUP=backup-20260322-030000  # Восстановление

# Обслуживание
make validate    # Проверка конфигурации
make health      # Проверка здоровья сервисов
make cleanup     # Очистка старых бэкапов

# Мониторинг
make monitoring-up   # Запуск мониторинга
make monitoring-down # Остановка мониторинга

# Разработка
make dev         # Запуск dev окружения
make dev-logs    # Логи dev окружения
```

## Структура

```
├── docker-compose.yml           # Production stack
├── docker-compose.monitoring.yml # Monitoring stack
├── Dockerfile                   # Paperclip image
├── Dockerfile.dev              # Development image
├── Makefile                   # Команды управления
├── opencode/                  # OpenCode configuration
│   ├── Dockerfile.opencode
│   └── opencode-config.json
├── scripts/
│   ├── backup/              # Backup scripts
│   │   ├── backup.sh       # Полный бэкап
│   │   ├── restore.sh      # Восстановление
│   │   ├── list-backups.sh  # Список бэкапов
│   │   └── cleanup.sh       # Очистка старых
│   ├── setup/               # (sudo) Installation scripts
│   ├── validate.sh         # Валидация конфигурации
│   └── healthcheck.sh
├── backups/                  # Бэкапы (не в git)
├── data/                      # Данные (не в git)
├── logs/                      # Логи (не в git)
├── DOCKER.md                  # Подробная документация (EN)
├── SERVER_SETUP.md            # Руководство по настройке (RU)
└── AGENTS.md                  # Руководство для AI-агентов
```

## Сервисы

| Сервис | Порт | Описание |
|--------|------|----------|
| Nginx | 3100, 4096 | Reverse proxy + Basic Auth |
| Paperclip | 3100 | Основное приложение (доступ через Nginx) |
| OpenCode | 4096 | AI агент (Groq API, доступ через Nginx) |

### Доступ к сервисам

| Сервис | URL | Пользователь | Пароль |
|--------|-----|--------------|--------|
| Paperclip | http://192.168.0.186:3100 | admin | paperclip |
| OpenCode | http://192.168.0.186:4096 | admin | paperclip |

### Мониторинг (опционально)

```bash
make monitoring-up
# или
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml --profile monitoring up -d
```

| Сервис | Порт | Описание |
|--------|------|----------|
| Prometheus | 9090 | Метрики (localhost only) |
| Grafana | 3000 | Визуализация (localhost only) |
| Alertmanager | 9093 | Оповещения (localhost only) |

## Backup система

### Создание бэкапа
```bash
make backup
# или
./scripts/backup/backup.sh
```

Бэкап включает:
- PostgreSQL база данных (`paperclip-db.sql.gz`)
- Redis данные (`dump.rdb`)
- Paperclip данные (`paperclip-data.tar.gz`)
- Конфигурационные файлы (`configs.tar.gz`)
- Манифест (`backup-manifest.json`)

### Ротация
- По умолчанию: 90 дней
- Настраивается через `BACKUP_RETENTION_DAYS` в `.env`

### Восстановление
```bash
# Список бэкапов
make list-backups

# Восстановление
make restore BACKUP=backup-20260322-030000

# Или интерактивно
./scripts/backup/restore.sh
```

## Документация

- [SERVER_SETUP.md](SERVER_SETUP.md) — Руководство по установке (русский)
- [DOCKER.md](DOCKER.md) — Подробная Docker документация
- [AGENTS.md](AGENTS.md) — Руководство для AI-агентов

## Требования

| Компонент | Минимум | Рекомендуется |
|-----------|---------|----------------|
| RAM | 4 GB | 8+ GB |
| CPU | 2 cores | 4+ cores |
| Disk | 20 GB | 50+ GB SSD |

## Лицензия

MIT
