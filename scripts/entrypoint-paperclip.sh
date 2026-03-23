#!/bin/bash
set -e

# Проверка DATABASE_URL
if [ -z "$DATABASE_URL" ]; then
    echo "ERROR: DATABASE_URL is required"
    exit 1
fi

# Запуск приложения с секретами из файлов
exec env \
    BETTER_AUTH_SECRET="$(cat /run/secrets/BETTER_AUTH_SECRET)" \
    SESSION_SECRET="$(cat /run/secrets/SESSION_SECRET)" \
    JWT_SECRET="$(cat /run/secrets/JWT_SECRET)" \
    ENCRYPTION_KEY="$(cat /run/secrets/ENCRYPTION_KEY)" \
    OPENCODE_API_PASSWORD="$(cat /run/secrets/OPENCODE_API_PASSWORD)" \
    GROQ_API_KEY="$(cat /run/secrets/GROQ_API_KEY)" \
    node --import ./server/node_modules/tsx/dist/loader.mjs server/dist/index.js
