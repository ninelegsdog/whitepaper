#!/bin/bash
# =============================================================================
# Paperclip Secret Generator
# =============================================================================
# This script generates secure secrets for Paperclip deployment
# Run this script before starting Paperclip for the first time
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SECRETS_DIR="${PROJECT_ROOT}/.secrets"
ENV_FILE="${PROJECT_ROOT}/.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# =============================================================================
# Utility Functions
# =============================================================================

generate_random_secret() {
    local length="${1:-32}"
    if command -v openssl > /dev/null 2>&1; then
        openssl rand -base64 "$length" | tr -d '\n'
    elif command -v head > /dev/null 2>&1 && command -v tr > /dev/null 2>&1; then
        head -c "$((length * 2))" /dev/urandom | base64 | tr -d '\n' | head -c "$length"
    else
        # Fallback: use /dev/urandom directly
        head -c "$length" /dev/urandom | xxd -p | tr -d '\n' | head -c "$length"
    fi
}

generate_uuid() {
    if command -v uuidgen > /dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v cat > /dev/null 2>&1; then
        # Generate UUID-like string
        cat /proc/sys/kernel/random/uuid 2>/dev/null || \
        printf '%04x%04x-%04x-%04x-%04x-%04x%04x%04x\n' \
            $((RANDOM % 65536)) $((RANDOM % 65536)) \
            $((RANDOM % 65536)) \
            $((RANDOM % 4096 + 16384)) \
            $((RANDOM % 65536)) $((RANDOM % 65536)) $((RANDOM % 65536)) $((RANDOM % 65536))
    fi
}

secure_permissions() {
    local file="$1"
    chmod 600 "$file" 2>/dev/null || true
}

# =============================================================================
# Secret Generation Functions
# =============================================================================

generate_better_auth_secret() {
    log_info "Generating BETTER_AUTH_SECRET..."
    local secret_file="${SECRETS_DIR}/BETTER_AUTH_SECRET"
    
    if [ -f "$secret_file" ]; then
        log_warning "BETTER_AUTH_SECRET already exists, skipping"
        return 0
    fi
    
    local secret
    secret=$(generate_random_secret 64)
    echo "$secret" > "$secret_file"
    secure_permissions "$secret_file"
    log_success "Created BETTER_AUTH_SECRET"
}

generate_db_password() {
    log_info "Generating database password..."
    local password_file="${SECRETS_DIR}/POSTGRES_PASSWORD"
    
    if [ -f "$password_file" ]; then
        log_warning "Database password already exists, skipping"
        return 0
    fi
    
    local password
    # Generate URL-safe password (alphanumeric only, no special chars)
    if command -v openssl > /dev/null 2>&1; then
        password=$(openssl rand -base64 48 | tr -d '=+/' | head -c 48)
    elif command -v head > /dev/null 2>&1 && command -v tr > /dev/null 2>&1; then
        password=$(head -c 96 /dev/urandom | base64 | tr -d '=+/' | head -c 48)
    else
        password=$(head -c 48 /dev/urandom | xxd -p | tr -d '\n' | head -c 48)
    fi
    echo "$password" > "$password_file"
    secure_permissions "$password_file"
    log_success "Created database password"
}

generate_jwt_secret() {
    log_info "Generating JWT secret..."
    local secret_file="${SECRETS_DIR}/JWT_SECRET"
    
    if [ -f "$secret_file" ]; then
        log_warning "JWT secret already exists, skipping"
        return 0
    fi
    
    local secret
    secret=$(generate_random_secret 64)
    echo "$secret" > "$secret_file"
    secure_permissions "$secret_file"
    log_success "Created JWT secret"
}

generate_encryption_key() {
    log_info "Generating encryption key..."
    local key_file="${SECRETS_DIR}/ENCRYPTION_KEY"
    
    if [ -f "$key_file" ]; then
        log_warning "Encryption key already exists, skipping"
        return 0
    fi
    
    local key
    key=$(generate_random_secret 32)
    echo "$key" > "$key_file"
    secure_permissions "$key_file"
    log_success "Created encryption key"
}

generate_session_secret() {
    log_info "Generating session secret..."
    local secret_file="${SECRETS_DIR}/SESSION_SECRET"
    
    if [ -f "$secret_file" ]; then
        log_warning "Session secret already exists, skipping"
        return 0
    fi
    
    local secret
    secret=$(generate_random_secret 64)
    echo "$secret" > "$secret_file"
    secure_permissions "$secret_file"
    log_success "Created session secret"
}

generate_replica_id() {
    log_info "Generating replica ID..."
    local id_file="${SECRETS_DIR}/REPLICA_ID"
    
    if [ -f "$id_file" ]; then
        log_warning "Replica ID already exists, skipping"
        return 0
    fi
    
    local replica_id
    replica_id=$(generate_uuid)
    echo "$replica_id" > "$id_file"
    secure_permissions "$id_file"
    log_success "Created replica ID: $replica_id"
}

# =============================================================================
# Docker Secrets Generation
# =============================================================================

generate_docker_secrets() {
    log_info "Generating Docker secrets..."
    
    local docker_secrets_dir="${PROJECT_ROOT}/docker/secrets"
    mkdir -p "$docker_secrets_dir"
    
    # Copy secrets to docker secrets directory (if using docker swarm)
    if [ -d "/run/secrets" ] || [ -f "/.dockerenv" ]; then
        log_info "Docker environment detected, secrets available at /run/secrets"
    else
        log_info "Docker secrets directory prepared at ${docker_secrets_dir}"
    fi
    
    log_success "Docker secrets generation complete"
}

# =============================================================================
# Tailscale Auth Key Generation
# =============================================================================

generate_tailscale_key() {
    log_info "Generating Tailscale auth key placeholder..."
    local key_file="${SECRETS_DIR}/TAILSCALE_AUTH_KEY"
    
    if [ -f "$key_file" ]; then
        log_warning "Tailscale auth key already exists, skipping"
        return 0
    fi
    
    # Placeholder - user needs to generate from Tailscale admin console
    echo "tskey-auth-k............" > "$key_file"
    secure_permissions "$key_file"
    log_success "Created Tailscale auth key placeholder"
    log_warning "Please update ${key_file} with your actual Tailscale auth key"
}

generate_opencode_password() {
    log_info "Generating OpenCode API password..."
    local password_file="${SECRETS_DIR}/OPENCODE_API_PASSWORD"
    
    if [ -f "$password_file" ]; then
        log_warning "OpenCode API password already exists, skipping"
        return 0
    fi
    
    local password
    password=$(generate_random_secret 32)
    echo "$password" > "$password_file"
    secure_permissions "$password_file"
    log_success "Created OpenCode API password"
}

generate_groq_api_key() {
    log_info "Generating GROQ API key placeholder..."
    local key_file="${SECRETS_DIR}/GROQ_API_KEY"
    
    if [ -f "$key_file" ]; then
        log_warning "GROQ API key already exists, skipping"
        return 0
    fi
    
    echo "gsk_YOUR_ACTUAL_KEY_HERE" > "$key_file"
    secure_permissions "$key_file"
    log_success "Created GROQ API key placeholder"
    log_warning "Please update ${key_file} with your actual API key"
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    echo ""
    echo "=========================================="
    echo "  Paperclip Secret Generator"
    echo "=========================================="
    echo ""
    
    # Check for required tools
    if ! command -v openssl > /dev/null 2>&1 && \
       ! command -v head > /dev/null 2>&1; then
        log_error "Required tools not found. Please install openssl or coreutils."
        exit 1
    fi
    
    # Create secrets directory
    mkdir -p "$SECRETS_DIR"
    log_info "Secrets directory: ${SECRETS_DIR}"
    
    # Generate all secrets
    generate_better_auth_secret
    generate_db_password
    generate_jwt_secret
    generate_encryption_key
    generate_session_secret
    generate_replica_id
    generate_tailscale_key
    generate_opencode_password
    generate_groq_api_key
    
    # Docker secrets
    generate_docker_secrets
    
    echo ""
    echo "=========================================="
    echo "  Secret Generation Complete!"
    echo "=========================================="
    echo ""
    log_success "All secrets have been generated"
    log_info "Secrets directory: ${SECRETS_DIR}"
    echo ""
    log_warning "IMPORTANT:"
    log_warning "  - NEVER commit .secrets/ to version control"
    log_warning "  - Keep your secrets safe and backed up"
    log_warning "  - Update Tailscale auth key with your actual key"
    log_warning "  - Update GROQ_API_KEY with your actual API key"
    echo ""
}

# Parse arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --force        Overwrite existing secrets"
        echo "  --list         List generated secrets"
        echo ""
        exit 0
        ;;
    --force)
        log_warning "Force mode - will regenerate all secrets"
        rm -f "${SECRETS_DIR}"/* 2>/dev/null || true
        main
        ;;
    --list)
        echo "Generated secrets:"
        if [ -d "$SECRETS_DIR" ]; then
            ls -la "$SECRETS_DIR"
        else
            echo "No secrets directory found"
        fi
        exit 0
        ;;
    *)
        main
        ;;
esac
