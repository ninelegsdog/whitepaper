# Этап 1: Сборка
FROM node:20-slim AS builder
WORKDIR /app

# Установка pnpm версии 9.15+, как того требуют исходники [1, 2]
RUN corepack enable && corepack prepare pnpm@9.15.0 --activate

# Сначала копируем только файлы зависимостей для эффективного кэширования слоев [3]
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY packages/ ./packages/

# Установка зависимостей и сборка проекта
RUN pnpm install --frozen-lockfile
RUN pnpm build

# Этап 2: Финальный защищенный образ
FROM node:20-slim
LABEL maintainer="paperclip-admin"
WORKDIR /app

# Настройка продакшн-окружения
ENV NODE_ENV=production
ENV PORT=3100

# Создание системного пользователя без прав root для безопасности [5]
RUN groupadd -r paperclip && useradd -r -g paperclip paperclip

# Копируем только необходимые артефакты из этапа сборки
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# Ограничение прав доступа к файлам
RUN chown -R paperclip:paperclip /app
USER paperclip

EXPOSE 3100
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://localhost:3100/health').then(r => r.ok ? process.exit(0) : process.exit(1))"

CMD ["node", "dist/server/index.js"]