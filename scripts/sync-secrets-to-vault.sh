#!/bin/bash
set -e

# Конфигурация Vault
export VAULT_ADDR='http://127.0.0.1:8200'
# Note: VAULT_TOKEN should be set as an environment variable before running this script
# export VAULT_TOKEN='your-vault-token-here'

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
