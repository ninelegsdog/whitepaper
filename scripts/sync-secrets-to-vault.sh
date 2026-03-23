#!/bin/bash
set -e

# Конфигурация Vault
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='your-token'

# Синхронизация всех секретов
for secret_file in .secrets/*; do
    secret_name=$(basename "$secret_file")
    secret_value=$(cat "$secret_file")
    vault kv put secret/paperclip/$secret_name value="$secret_value"
    echo "✓ Синхронизирован: $secret_name"
done

echo "Все секреты синхронизированы с Vault!"
