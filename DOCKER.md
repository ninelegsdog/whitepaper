# Docker Deployment Guide for Paperclip

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Development Setup](#development-setup)
- [Production Deployment](#production-deployment)
- [Monitoring Setup](#monitoring-setup)
- [Security Configuration](#security-configuration)
- [Scaling](#scaling)
- [Troubleshooting](#troubleshooting)

## Overview

This repository contains Docker configurations for deploying Paperclip, an AI agent orchestration platform. The setup is designed for:

- **Maximum Security**: Non-root users, read-only filesystems, dropped capabilities
- **Scalability**: Multi-instance deployment with load balancing
- **VPN-Only Access**: Traefik reverse proxy with Tailscale integration
- **Monitoring**: Prometheus + Grafana for observability
- **CI/CD**: GitHub Actions workflows for automated builds and deployment
- **AI Integration**: OpenCode with Groq API (free tier) for AI agent capabilities

## Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 4 cores | 8+ cores |
| RAM | 8 GB | 16+ GB |
| Disk | 20 GB | 50+ GB SSD |
| Docker | 24.0 | 25.0+ |
| Docker Compose | 2.20 | 2.25+ |

### Required Software

```bash
# Docker Engine
curl -fsSL https://get.docker.com | sh

# Docker Compose plugin
apt install docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/paperclipai/paperclip.git
cd paperclip
```

### 2. Generate Secrets

```bash
chmod +x scripts/generate-secrets.sh
./scripts/generate-secrets.sh
```

### 3. Configure Environment

```bash
cp .env.example .env
# Edit .env with your settings
nano .env
```

### 4. Start Development Environment

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

### 5. Access Paperclip

Open http://localhost:3100 in your browser.

## OpenCode Integration

Paperclip integrates with OpenCode to provide AI agent capabilities using free-tier Groq API.

### Supported Models

| Model | Provider | Context | Use Case |
|-------|---------|---------|----------|
| `llama-3.3-70b-versatile` | Groq | 128k | General purpose, coding |
| `mixtral-8x7b-32768` | Groq | 32k | Fast inference |
| `gemma2-9b-it` | Groq | 8k | Lightweight tasks |

### OpenCode API

OpenCode runs in server mode and exposes an HTTP API for Paperclip integration.

**Endpoint**: `http://opencode:4096` (internal) or `http://localhost:4096` (external)

**Authentication**: Bearer token (password from `OPENCODE_API_PASSWORD`)

```bash
# Example API call
curl -X POST http://localhost:4096/tui/append-prompt \
  -H "Authorization: Bearer $OPENCODE_API_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{"text": "Analyze this code..."}'
```

### Configuration

Edit `opencode/opencode-config.json` to change the default model:

```json
{
  "defaultProvider": "groq",
  "model": "groq/llama-3.3-70b-versatile"
}
```

### Available Tools

- `bash` - Execute shell commands
- `write` - Create/edit files
- `read` - Read file contents
- `edit` - Modify specific parts of files
- `glob` - Find files by pattern
- `grep` - Search file contents
- `websearch` - Search the web

## Development Setup

### Development Stack

The development environment includes:

- Paperclip with hot-reload enabled
- PostgreSQL for database
- Redis for caching
- Mailhog for email catching
- Redis Commander for Redis GUI

### Start Development

```bash
# Start only development services
docker compose -f docker-compose.dev.yml --profile development up -d

# View logs
docker compose -f docker-compose.dev.yml logs -f

# Stop services
docker compose -f docker-compose.dev.yml down
```

### Hot Reload

Source code is mounted as a volume, enabling hot-reload:

```bash
# Edit files locally
nano server/src/index.ts

# Changes are reflected immediately
```

### Debug Mode

Connect to Node.js debugger:

```bash
# VS Code launch.json
{
  "type": "node",
  "request": "attach",
  "name": "Docker Attach",
  "port": 9229,
  "remoteRoot": "/app"
}
```

## Production Deployment

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Tailscale VPN Network                        │
│                    (paperclip.local)                            │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Traefik Reverse Proxy                       │
│                     (Load Balancer)                             │
└─────────────────────────────────────────────────────────────────┘
                    │                    │
        ┌───────────┴───────┐    ┌───────┴───────────┐
        │  Paperclip #1     │    │  Paperclip #2    │
        │  (Container)     │    │  (Container)     │
        └───────────┬───────┘    └───────┬───────────┘
                    │                    │
        ┌───────────┴────────────────────┴───────┐
        │         Shared Data Volume             │
        │         (/paperclip)                    │
        └─────────────────────────────────────────┘
                    │                    │
        ┌───────────┴───────┐    ┌───────┴───────────┐
        │   PostgreSQL     │    │     Redis         │
        │   (Database)     │    │    (Cache)        │
        └───────────────────┘    └───────────────────┘
                    │                    │
        ┌───────────┴───────┐
        │    OpenCode       │
        │    (Groq API)     │
        │   :4096           │
        └───────────────────┘
```
┌─────────────────────────────────────────────────────────────────┐
│                    Tailscale VPN Network                        │
│                    (paperclip.local)                           │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Traefik Reverse Proxy                       │
│                     (Load Balancer)                            │
└─────────────────────────────────────────────────────────────────┘
                    │                    │
        ┌───────────┴───────┐    ┌───────┴───────────┐
        │  Paperclip #1    │    │  Paperclip #2    │
        │  (Container)     │    │  (Container)     │
        └───────────┬───────┘    └───────┬───────────┘
                    │                    │
        ┌───────────┴────────────────────┴───────┐
        │         Shared Data Volume             │
        │         (/paperclip)                    │
        └─────────────────────────────────────────┘
                    │                    │
        ┌───────────┴───────┐    ┌───────┴───────────┐
        │   PostgreSQL     │    │     Redis         │
        │   (Database)      │    │    (Cache)        │
        └───────────────────┘    └───────────────────┘
```

### Production Setup

#### 1. Prepare Server

```bash
# SSH to your server
ssh user@your-server

# Create paperclip directory
sudo mkdir -p /opt/paperclip
sudo chown $USER:$USER /opt/paperclip

# Create data directories
mkdir -p data/paperclip data/postgres data/redis
```

#### 2. Clone Repository

```bash
cd /opt/paperclip
git clone https://github.com/paperclipai/paperclip.git .
```

#### 3. Configure Secrets

```bash
chmod +x scripts/generate-secrets.sh
./scripts/generate-secrets.sh

# Edit environment file
cp .env.example .env
nano .env
```

#### 4. Set Up Tailscale

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate
tailscale up --authkey=<your-auth-key>

# Note the Tailscale IP for DNS configuration
tailscale ip -4
```

#### 5. Start Production Stack

```bash
# Create backend network
docker network create paperclip-backend || true

# Start all services
docker compose -f docker-compose.yml up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

### Health Check

```bash
# Check health endpoint
curl https://paperclip.local/health

# Check API
curl https://paperclip.local/api/health
```

## Monitoring Setup

### Start Monitoring Stack

```bash
# Start monitoring services alongside main stack
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d
```

### Access Monitoring Tools

| Tool | URL | Default Credentials |
|------|-----|-------------------|
| Grafana | https://grafana.paperclip.local | admin / (from .env) |
| Prometheus | https://prometheus.paperclip.local | - |
| Traefik Dashboard | https://traefik.paperclip.local | - |

### Create Grafana Dashboard

1. Log in to Grafana
2. Go to Dashboards → Import
3. Import the dashboard from `grafana/dashboards/paperclip.json`

## Security Configuration

### Container Security Features

| Feature | Implementation |
|---------|----------------|
| Non-root user | `USER node` (UID 1000) |
| Read-only rootfs | `read_only: true` |
| No new privileges | `security_opt: no-new-privileges:true` |
| Drop capabilities | `cap_drop: ALL` |
| tmpfs /tmp | `tmpfs: /tmp:size=100M,mode=1777` |
| Resource limits | CPU, memory constraints |
| Healthcheck | HTTP endpoint monitoring |

### Network Security

```yaml
networks:
  backend:
    internal: true  # No external access
```

### Secrets Management

```bash
# Generate secrets
./scripts/generate-secrets.sh

# Secrets are stored in .secrets/ directory
ls -la .secrets/
```

### Firewall Configuration

```bash
# Allow only Tailscale
ufw allow from 100.64.0.0/10 to any port 443,80
ufw deny 443
ufw deny 80
```

## Scaling

### Add More Instances

Edit `docker-compose.yml`:

```yaml
services:
  paperclip-3:
    # ... copy configuration from paperclip-2
    environment:
      - REPLICA_ID=3
```

### Update Traefik

Update `traefik/dynamic/paperclip.yml`:

```yaml
http:
  services:
    paperclip-service:
      loadBalancer:
        servers:
          - url: "http://paperclip-1:3100"
          - url: "http://paperclip-2:3100"
          - url: "http://paperclip-3:3100"  # Add new instance
```

### Rolling Update

```bash
# Update one instance at a time
docker compose up -d --no-deps paperclip-1
sleep 30
docker compose up -d --no-deps paperclip-2
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs paperclip-1

# Check resource limits
docker stats

# Restart service
docker compose restart paperclip-1
```

### Health Check Fails

```bash
# Run health check script
docker compose exec paperclip-1 /scripts/healthcheck.sh

# Check port accessibility
docker compose exec paperclip-1 curl -f http://localhost:3100/health
```

### Database Connection Issues

```bash
# Check database health
docker compose exec db pg_isready -U paperclip

# View database logs
docker compose logs db

# Check connection string
docker compose exec paperclip-1 env | grep DATABASE
```

### High Memory Usage

```bash
# Check container memory
docker stats --no-stream

# Adjust memory limits in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 2G  # Reduce from 4G
```

### Clear All Data

```bash
# Stop all containers
docker compose down

# Remove volumes (WARNING: deletes all data)
docker compose down -v

# Clean up Docker
docker system prune -a --volumes
```

## Maintenance

### Update Paperclip

```bash
# Pull latest code
git pull origin main

# Rebuild images
docker compose build

# Restart services
docker compose up -d
```

### Backup Database

```bash
# Create backup
docker compose exec -T db pg_dump -U paperclip > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore backup
cat backup_20240101_120000.sql | docker compose exec -T db psql -U paperclip
```

### View Resource Usage

```bash
# Real-time stats
docker stats

# Disk usage
docker system df

# Logs with timestamps
docker compose logs -t
```

## CI/CD

### GitHub Actions

The repository includes three workflows:

1. **docker-build.yml** - Builds and pushes images on push/PR
2. **docker-deploy.yml** - Deploys to staging/production
3. **docker-test.yml** - Runs tests in Docker containers

### Required Secrets

```bash
# GitHub Repository Settings → Secrets and variables → Actions

STAGING_HOST=staging.example.com
STAGING_USER=ubuntu
STAGING_SSH_KEY=<private-key>
PRODUCTION_HOST=example.com
PRODUCTION_USER=ubuntu
PRODUCTION_SSH_KEY=<private-key>
```

## License

MIT License - see LICENSE file for details.
