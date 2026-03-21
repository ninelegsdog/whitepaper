# Whitepaper

Биржа предсказаний на блокчейне

## О проекте

Whitepaper - это децентрализованная платформа для создания и торговли предсказательными рынками. Пользователи могут создавать рынки на любые события, торговать долями исходов и получать вознаграждение за правильные предсказания.

## Технологический стек

- **Backend**: Node.js, TypeScript, Express
- **Frontend**: React, TypeScript, Vite
- **Blockchain Integration**: Ethereum, Web3.js/Ethers.js
- **Database**: PostgreSQL с Prisma ORM
- **Real-time коммуникации**: WebSocket (Socket.IO)
- **Контейнеризация**: Docker, Docker Compose
- **Тестирование**: Vitest/Jest, Testing Library
- **Линтинг и форматирование**: ESLint, Prettier
- **Type checking**: TypeScript strict mode
- **CI/CD**: GitHub Actions

## Структура проекта

```
whitepaper/
├── packages/
│   ├── server/          # Backend сервер (Node.js/Express)
│   ├── client/          # Frontend приложение (React/Vite)
│   ├── shared/          # Общие типы и утилиты
│   └── contracts/       # Смарт-контракты (Solidity)
├── docker-compose.yml   # Конфигурация Docker Compose
├── Dockerfile           # Multi-stage Dockerfile для production
├── .env.example         # Пример файла переменных окружения
├── pnpm-workspace.yaml  # Конфигурация pnpm workspace
├── pnpm-lock.yaml       # Файл блокировки зависимостей
├── AGENTS.md            # Руководство для агентов кодинга
└── README.md            # Этот файл
```

## Установка и запуск

### Требования

- Node.js v20 или выше
- pnpm v9.15 или выше
- Docker и Docker Compose (для запуска с контейнерами)
- PostgreSQL (если запускаете без Docker)
- Ethereum кошелек (MetaMask или подобный) для взаимодействия с блокчейном

### Локальная разработка

1. Клонируйте репозиторий:
   ```bash
   git clone <repository-url>
   cd whitepaper
   ```

2. Установите зависимости:
   ```bash
   pnpm install
   ```

3. Скопируйте пример переменных окружения:
   ```bash
   cp .env.example .env
   ```
   Отредактируйте `.env` файл, добавив необходимые значения:
   - Подключение к базе данных
   - Приватные ключи для блокчейн-транзакций (для тестнет)
   - Секретные ключи для JWT и других криптографических операций
   - URL ноды Ethereum (Infura, Alchemy или локальный узел)

4. Запустите базу данных и другие сервисы через Docker Compose (рекомендуется):
   ```bash
   docker-compose up -d
   ```

5. Выполните миграции базы данных:
   ```bash
   pnpm dlx prisma migrate dev
   ```

6. Запустите разработческие серверы:
   ```bash
   pnpm dev
   ```
   Это запустит оба бекенд и фронтенд в режиме разработки с горячей перезагрузкой.

   Бекенд будет доступен по адресу: http://localhost:3100
   Фронтенд будет доступен по адресу: http://localhost:5173

### Запуск с помощью Docker

Для production окружения можно использовать готовый Docker образ:

```bash
# Сборка образа
docker build -t whitepaper .

# Запуск контейнера
docker run -p 3100:3100 --env-file .env whitepaper
```

Или используя Docker Compose:
```bash
docker-compose up
```

## Доступные скрипты

В корневом `package.json` определены следующие скрипты:

- `pnpm install` - Установка всех зависимостей monorepo
- `pnpm dev` - Запуск всех приложений в режиме разработки
- `pnpm build` - Сборка всех приложений для production
- `pnpm test` - Запуск всех тестов
- `pnpm lint` - Запуск ESLint для проверки кода
- `pnpm lint:fix` - Автоматическое исправление ошибок ESLint
- `pnpm format` - Форматирование кода с помощью Prettier
- `pnpm typecheck` - Проверка типов TypeScript

Для работы с конкретными пакетами можно использовать фильтр pnpm:
- `pnpm --filter @whitepaper/server dev` - Запуск только бекенда
- `pnpm --filter @whitepaper/client dev` - Запуск только фронтенда
- `pnpm --filter @whitepaper/shared test` - Тесты только для shared пакета

## Руководство по вкладке

Мы приветствуем вкладки в проект! Пожалуйста, следуйте этим рекомендациям:

1. Форкните репозиторий и создайте свою ветку от `main`
2. Следуйте [руководству стиля кода](./AGENTS.md) при написании кода
3. Пишитеunit тесты для новой функциональности
4. Обновляйте документацию при необходимости
5. Убедитесь, что все тесты проходят перед отправкой pull request
6. Следуйте conventional commits при написании сообщений коммитов

### Процесс отправки изменений

1. Сделайте fork репозитория
2. Создайте ветку для своей функции/исправления: `git checkout -b feature/amazing-feature`
3. Внесите изменения и сделайте коммиты: `git commit -m 'feat: добавитьamazing feature'`
4. Отправьте ветку в ваш fork: `git push origin feature/amazing-feature`
5. Откройте pull request в основной репозиторий

## Лицензия

Этот проект лицензирован под лицензией MIT - см. файл [LICENSE](LICENSE) для подробной информации.

## Контакт

Если у вас есть вопросы или предложения, пожалуйста, создайте issue в репозитории или свяжитесь с командой разработки.

---

Разработано с ❤️ командой Whitepaper