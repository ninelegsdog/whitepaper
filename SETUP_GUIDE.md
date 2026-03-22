# Руководство по настройке Paperclip

## Порядок выполнения скриптов

### Первый этап: Установка базовых компонентов (с sudo)

```bash
# 1. Установка Docker + Docker Compose
sudo bash /home/algtro/whitepaper/scripts/setup/01-install-docker.sh
# ⚠️ ВАЖНО: Выйдите и войдите снова в систему после этого!

# 2. Установка Tailscale VPN
sudo bash /home/algtro/whitepaper/scripts/setup/02-install-tailscale.sh
# ⚠️ Потребуется авторизация в браузере

# 3. Создание директорий
sudo bash /home/algtro/whitepaper/scripts/setup/03-create-dirs.sh

# 4. Настройка Firewall (UFW)
sudo bash /home/algtro/whitepaper/scripts/setup/04-setup-firewall.sh
# ⚠️ Потребуется подтверждение для активации UFW
```

### Второй этап: Генерация секретов (без sudo)

```bash
cd /home/algtro/whitepaper

# 5. Генерация секретов
./scripts/generate-secrets.sh

# 6. Отредактируйте .env файл - добавьте обязательные ключи:
#    - GROQ_API_KEY (https://console.groq.com/keys)
#    - TAILSCALE_AUTH_KEY (https://login.tailscale.com/admin/settings/keys)
nano .env
```

### Третий этап: Запуск (без sudo)

```bash
# 7. Загрузка Docker образов
./scripts/setup/05-pull-images.sh

# 8. Запуск приложения
./scripts/run.sh
```

## Необходимые ключи

| Ключ | Где получить | Бесплатный? |
|------|--------------|-------------|
| `GROQ_API_KEY` | https://console.groq.com/keys | Да |
| `TAILSCALE_AUTH_KEY` | https://login.tailscale.com/admin/settings/keys | Да |

## Важные замечания

1. **После шага 1** - требуется перелогин для применения группы docker
2. **Шаг 4** (firewall) - требует подтверждение, т.к. активирует UFW
3. **Шаг 5** - генерирует `.env` файл автоматически из секретов

## Проверка после установки

```bash
# Статус контейнеров
docker compose ps

# Логи
docker compose logs -f

# Health check
curl http://localhost:3100/health
```
