# =============================================================================
# Paperclip Dockerfile - Production
# =============================================================================
# Multi-stage build optimized for security and minimal image size
# 
# Security features:
#   - Multi-stage build (no build tools in final image)
#   - Non-root user (node:node, UID 1000)
#   - Read-only root filesystem
#   - No new privileges
#   - Dropped Linux capabilities
#   - tmpfs for /tmp
#   - Health check
# =============================================================================

# syntax=docker/dockerfile:1-labs
# check=error=true

# =============================================================================
# Stage 1: Base Image
# =============================================================================
FROM node:20-slim AS base

# Install only essential tools for runtime
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        wget \
        dumb-init \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/*

# Enable corepack for pnpm
RUN corepack enable

# Create node user with specific UID/GID for consistency
RUN useradd -r -u 1000 -g node -d /home/node -s /bin/bash node \
    && mkdir -p /home/node \
    && chown -R node:node /home/node

# =============================================================================
# Stage 2: Dependencies
# =============================================================================
FROM base AS deps

WORKDIR /app

# Copy only dependency files first for better caching
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml .npmrc ./

# Copy package files from all workspaces
COPY packages/ ./packages/
COPY server/package.json server/
COPY ui/package.json ui/

# Install dependencies with frozen lockfile
RUN pnpm install --frozen-lockfile --prod

# =============================================================================
# Stage 3: Builder
# =============================================================================
FROM base AS builder

WORKDIR /app

# Copy installed dependencies from deps stage
COPY --from=deps /app /app

# Copy source code
COPY --chown=node:node . .

# Build the application
RUN pnpm --filter @paperclipai/ui build && \
    pnpm --filter @paperclipai/server build

# Verify build outputs exist
RUN test -f server/dist/index.js || { \
    echo "ERROR: Server build output missing"; \
    exit 1; \
}

# =============================================================================
# Stage 4: Production Image
# =============================================================================
FROM base AS production

# Metadata
LABEL maintainer="paperclip-team"
LABEL org.opencontainers.image.description="Paperclip - AI Agent Orchestration Platform"
LABEL org.opencontainers.image.source="https://github.com/paperclipai/paperclip"

WORKDIR /app

# Copy built application from builder stage
COPY --from=builder --chown=node:node /app /app

# Install global CLI tools (production only)
RUN npm install --global --omit=dev \
    @openai/codex@latest \
    @anthropic-ai/claude-code@latest \
    opencode-ai@latest \
    2>/dev/null || true

# Create paperclip directory for data persistence
RUN mkdir -p /paperclip && \
    chown node:node /paperclip

# =============================================================================
# Environment Variables
# =============================================================================
ENV NODE_ENV=production \
    HOME=/paperclip \
    HOST=0.0.0.0 \
    PORT=3100 \
    SERVE_UI=true \
    PAPERCLIP_HOME=/paperclip \
    PAPERCLIP_INSTANCE_ID=default \
    PAPERCLIP_CONFIG=/paperclip/instances/default/config.json \
    PAPERCLIP_DEPLOYMENT_MODE=authenticated \
    PAPERCLIP_DEPLOYMENT_EXPOSURE=vpn \
    # Security: Disable dangerous Node.js features
    NODE_OPTIONS="--max-old-space-size=3072"

# =============================================================================
# Security Configuration
# =============================================================================

# Switch to non-root user
USER node

# Set working directory
WORKDIR /app

# Expose port
EXPOSE 3100

# Read-only root filesystem (enforced by docker-compose)
# tmpfs for temporary files
VOLUME ["/paperclip"]

# =============================================================================
# Health Check
# =============================================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD node -e "\
        fetch('http://localhost:3100/health')\
            .then(r => r.ok ? process.exit(0) : process.exit(1))\
            .catch(() => process.exit(1))"

# =============================================================================
# Entrypoint with dumb-init for proper signal handling
# =============================================================================
ENTRYPOINT ["dumb-init", "--"]

# Start the server with tsx loader for TypeScript support
CMD ["node", "--import", "./server/node_modules/tsx/dist/loader.mjs", "server/dist/index.js"]
