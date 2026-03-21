# Paperclip Docker Configuration

Docker-конфигурация для развёртывания [Paperclip](https://github.com/paperclipai/paperclip) — платформы оркестрации AI-агентов на домашнем сервере.

## Особенности

- **Бесплатные AI модели** — Groq API (Llama 3.3 70B)
- **VPN-only доступ** — Tailscale для безопасного подключения
- **Минимальные требования** — 7GB RAM, 2+ CPU
- **Максимальная безопасность** — non-root контейнеры, read-only fs, dropped capabilities

## Быстрый старт

```bash
# Клонирование
git clone https://github.com/ninelegsdog/whitepaper.git
cd whitepaper

# Установка Docker (sudo)
sudo ./scripts/setup/01-install-docker.sh

# Настройка Tailscale (sudo)
sudo ./scripts/setup/02-install-tailscale.sh

# Конфигурация
cp .env.example .env
nano .env  # Заполните GROQ_API_KEY и TAILSCALE_AUTH_KEY

# Запуск
docker compose up -d
```

## Структура

```
├── docker-compose.yml      # Production stack
├── Dockerfile              # Paperclip image
├── Dockerfile.opencode     # OpenCode image
├── opencode/               # OpenCode configuration
│   ├── Dockerfile.opencode
│   └── opencode-config.json
├── traefik/               # Reverse proxy config
├── scripts/                # Setup scripts
│   ├── setup/             # (sudo) Installation scripts
│   ├── run.sh            # Start script
│   └── generate-secrets.sh
├── DOCKER.md             # Подробная документация (EN)
├── SERVER_SETUP.md       # Руководство по настройке (RU)
└── AGENTS.md            # Руководство для AI-агентов
```

## Сервисы

| Сервис | Порт | Описание |
|--------|------|----------|
| Paperclip | 3100 | Основное приложение |
| OpenCode | 4096 | AI агент (Groq API) |
| Traefik | 80/443 | Reverse proxy |

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
