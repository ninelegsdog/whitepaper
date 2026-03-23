#!/bin/bash
set -e

# Чтение секретов и экспорт переменных окружения
export GROQ_API_KEY=$(cat /run/secrets/GROQ_API_KEY 2>/dev/null || echo "")
export OPENCODE_API_PASSWORD=$(cat /run/secrets/OPENCODE_API_PASSWORD 2>/dev/null || echo "")

# Запуск OpenCode
exec opencode serve --hostname 0.0.0.0 --port 4096
