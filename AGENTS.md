# Agent Guidelines for Whitepaper Project

## Commands

### Installation
```bash
pnpm install
```

### Development
```bash
pnpm dev
```

### Build
```bash
pnpm build
```

### Test
```bash
pnpm test
```

### Run a single test
```bash
# If using Vitest (common with Vite)
pnpm test -- --run tests/yourTestFile.test.ts

# If using Jest
pnpm test -- --testNamePattern="your test pattern"

# If using other test runners, adjust accordingly
```

### Lint
```bash
pnpm lint
```

### Fix lint
```bash
pnpm lint:fix
```

### Format
```bash
pnpm format
```

### Type checking
```bash
pnpm typecheck
```

## Code Style Guidelines

### Language
- We use TypeScript for all new code (.ts, .tsx files)
- JavaScript files are allowed only for configuration or temporary scripts
- TypeScript strict mode is enabled in tsconfig.json

### Formatting
- We use Prettier for code formatting
- Configuration is in .prettierrc
- Run `pnpm format` to format all files
- Format on save is recommended in editor settings

### Imports
- Absolute imports are preferred over relative imports when importing from within the same package
- Use the following order for imports (with blank lines between groups):
  1. Built-in Node.js modules (if any)
  2. External dependencies
  3. Internal packages (using workspace aliases)
  4. Relative imports within the same package
- Never use relative imports to escape a package (use workspace aliases instead)
- Import types separately when using `typeof` or when only importing types

### Types
- Define explicit types for function parameters and return values
- Avoid using `any` unless absolutely necessary. If you must use `any`, add a comment explaining why
- Use interfaces for object shapes that might be extended or implemented
- Use type aliases for complex types, unions, tuples, and mapped types
- Prefer `const` assertions for literal objects when widening is not desired
- Avoid naming types with `I` prefix (e.g., use `User` not `IUser`)

### Naming Conventions
- Use camelCase for variables, functions, methods, and parameters
- Use PascalCase for classes, types, interfaces, and React components
- Use UPPER_SNAKE_CASE for constants (both enum values and const variables)
- File names: use kebab-case for TypeScript and JavaScript files
- Test files: append `.test.ts` or `.spec.ts` to the base name
- Configuration files: use appropriate extensions (.json, .rc, .config.ts)

### Error Handling
- Handle errors appropriately; do not leave try-catch blocks empty
- When throwing errors, use the built-in Error class or extend it for domain-specific errors
- In asynchronous code, always catch or propagate errors (avoid fire-and-forget)
- For promises, prefer async/await over .then() chains for better error handling
- Validate inputs at the boundaries of your functions/modules
- Use custom error classes for recoverable errors that callers should handle

### Comments
- Write clear and concise comments for complex logic or non-obvious solutions
- Use TODO comments for future work and include a ticket number if applicable (e.g., // TODO: TICKET-123)
- Remove commented-out code before committing
- Use JSDoc for public APIs and complex functions
- Avoid commenting what the code does; explain why it does it

### Git
- Write clear, concise commit messages in conventional commits format
- Format: <type>(<scope>): <subject>
- Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
- Keep subject line under 50 characters, wrap body at 72 characters
- Reference issues/pull requests in the body when applicable
- Never commit secrets, keys, or sensitive information

## Testing
- Write unit tests for all new functions and components
- Aim for high test coverage but prioritize testing critical paths
- Use descriptive test names that explain the expected behavior (given/when/then)
- Test one thing per test case
- Mock external dependencies and side effects
- Test both positive and negative cases
- For React components, test behavior not implementation details
- Use testing-library principles when applicable

## Dependencies
- Use pnpm to manage dependencies (lockfile is pnpm-lock.yaml)
- Add new dependencies with `pnpm add <package>` (or `-D` for dev dependencies)
- Regularly update dependencies with `pnpm update --latest`
- Prefer exact versions in package.json for stable dependencies
- Audit dependencies regularly with `pnpm audit`

## Docker
- The project uses Docker for containerization (see Dockerfile)
- To build the image: `docker build -t whitepaper .`
- To run the container: `docker run -p 3100:3100 whitepaper`
- The Dockerfile uses multi-stage builds for smaller production images
- Development should typically not use Docker; use pnpm dev directly

## Monitoring
- The Dockerfile includes a HEALTHCHECK that checks the /health endpoint
- Ensure that the health endpoint is implemented in the server
- Health check should verify critical dependencies (database, external services)
- Consider adding metrics endpoints for Prometheus if applicable

## Security
- Do not commit secrets or keys to the repository
- Use environment variables for configuration (see .env.example)
- Validate and sanitize all user inputs
- Use parameterized queries to prevent SQL injection
- Implement proper authentication and authorization
- Keep dependencies updated to avoid known vulnerabilities
- Follow OWASP guidelines for web application security

## Additional Notes
- This is a monorepo managed by pnpm. Workspace packages are in the `packages/` directory
- The main server entry point is at `packages/server/src/index.ts` (adjust based on actual structure)
- Client applications (if any) would be in separate packages under `packages/`
- Shared types and utilities should be in a shared package (e.g., `packages/shared`)
- Configuration files for the monorepo are at the root: pnpm-workspace.yaml, turbo.json (if using Turborepo)
- When in doubt about existing patterns, look at similar code in the codebase
- Run `pnpm lint` and `pnpm typecheck` before submitting code for review