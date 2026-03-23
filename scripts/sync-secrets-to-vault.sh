#!/bin/bash
set -e

# Конфигурация Vault
export VAULT_ADDR='http://127.0.0.1:8200'
# Читаем токен из файла .vault-token, если он существует
if [ -f ".vault-token" ]; then
    export VAULT_TOKEN=$(cat .vault-token)
elif [ -z "$VAULT_TOKEN" ]; then
    echo "Ошибка: VAULT_TOKEN не установлен. Создайте файл .vault-token с вашим токеном или установите переменную окружения VAULT_TOKEN"
    exit 1
fi

# Синхронизация всех секретов
for secret_file in .secrets/*; do
    secret_name=$(basename "$secret_file")
    secret_value=$(cat "$secret_file")
    curl -s --request POST "$VAULT_ADDR/v1/secret/data/paperclip/$secret_name" \
        --data "{\"data\": {\"value\": \"$secret_value\"}}" \
        -H "X-Vault-Token: $VAULT_TOKEN" > /dev/null
    echo "✓ Синхронизирован: $secret_name"
done

echo "Все секреты синхронизированы с Vault!"
