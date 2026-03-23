#!/bin/bash
set -e

# Чтение секретов из файлов и экспорт переменных окружения
for secret_file in /run/secrets/*; do
    if [ -f "$secret_file" ]; then
        secret_name=$(basename "$secret_file")
        export "$secret_name"="$(cat "$secret_file")"
    fi
done

# Запуск основного приложения
exec "$@"
