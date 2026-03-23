# Quickstart Guide

## Быстрый старт (3 команды)

```bash
# 1. Проверить конфигурацию
make validate

# 2. Запустить все сервисы
make up

# 3. Запустить мониторинг (опционально)
make monitoring-up
```

## Основные команды

| Команда | Описание |
|---------|----------|
| `make up` | Запустить основной стек |
| `make down` | Остановить все сервисы |
| `make restart` | Перезапустить все |
| `make status` | Показать статус контейнеров |
| `make logs` | Смотреть логи (в реальном времени) |

## Логи отдельных сервисов

```bash
make logs-opencode  # OpenCode
make logs-app       # Paperclip
make logs-db        # PostgreSQL
make logs-redis     # Redis
```

## Доступные сервисы

| Сервис | URL | Логин | Пароль |
|--------|-----|-------|--------|
| Paperclip | http://192.168.0.186:3100 | admin | paperclip |
| OpenCode | http://192.168.0.186:4096 | - | из OPENCODE_API_PASSWORD |
| Grafana | http://192.168.0.186:3000 | admin | из GRAFANA_PASSWORD |
| Prometheus | http://192.168.0.186:9090 | - | - |

## Устранение проблем

```bash
# Проверить статус
make status

# Проверить здоровье сервисов
make health

# Посмотреть логи конкретного сервиса
docker compose logs -f paperclip-app

# Перезапустить конкретный сервис
docker compose restart paperclip-app
```

## Переменные окружения

Файл `.env` должен содержать:

- `GRAFANA_PASSWORD` - пароль для Grafana
- `POSTGRES_PASSWORD` - пароль для PostgreSQL
- `BETTER_AUTH_SECRET` - ключ для аутентификации
- `SESSION_SECRET` - ключ для сессий
- `JWT_SECRET` - ключ для JWT токенов

Если получаете ошибку "required variable ... is missing a value", добавьте её в `.env`.

## Полезные ссылки

- Документация: `DOCKER.md`
- Структура проекта: `PROJECT_STRUCTURE.md`
- Makefile: `Makefile`
