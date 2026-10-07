---
name: be-setup
description: Use when scaffolding a new Node.js backend project from scratch. Walks through language / database / ORM / validation / logger / test selections, scaffolds an Express app manually (no official CLI), and optionally hands off to be-boilerplate, then be-auth.
---

# be-setup

Default: **pin every dependency to its latest stable version at install time.** No caret ranges for the initial scaffold - reproducible installs first.

## Contents

**Setup** - preconditions and target location.
- [Prerequisites](#prerequisites) - Node, package manager, `source-code/`, database reachable, network.
- [Working directory](#working-directory) - target project under `source-code/`.

**Workflow** - selections → confirm → scaffold → boilerplate → auth → CLAUDE.md.
- [1. Selections](#1-selections) - language / DB / ORM / validation / logger / test.
- [2. Confirmation](#2-confirmation) - echo selection and get approval.
- [3. Scaffold](#3-scaffold) - manual Express skeleton, path aliases, DB client, middleware, scripts.
- [4. Boilerplate routes](#4-boilerplate-routes-optional) - hand off to `be-boilerplate`, auth routes stubbed.
- [5. Authentication decision](#5-authentication-decision-optional) - wire now via `be-auth` (replaces stubs) or defer.
- [6. CLAUDE.md](#6-claudemd) - record selections.

**I/O & verification** - closing loop.
- [Input](#input) - none (greenfield).
- [Output](#output) - skeleton, config, `CLAUDE.md`.
- [Verification](#verification) - dev / typecheck / lint / test / build.

## Prerequisites

- **Node.js** - LTS or newer on PATH (`node -v`).
- **Package manager** - one of `pnpm` (default), `npm`, `yarn` installed globally. Verify with `<pm> -v` before scaffolding.
- **`source-code/` directory** at repo root - create it if missing (all projects live under it, never at the repo root).
- **Database reachable** - for PostgreSQL, a local Postgres (`psql -V`) or a connection string the user will paste. For MongoDB, a local `mongod` or Atlas URI. The skill does not install a DB engine - it only wires the client.
- **Network access** - npm registry fetch for installs.

## Working directory

Scaffold into `source-code/<project-name>/` - never at the repo root. Short version:

- Confirm `source-code/` exists at the repo root (create if missing).
- Confirm `source-code/<project-name>/` does not exist yet - if it does, ask (new name / resume / overwrite).
- Create the directory: `mkdir source-code/<name> && cd source-code/<name>`.
- Initialize `package.json`: `pnpm init` (accept defaults, edit `name` and `type: "module"`).
- All further commands run inside `source-code/<name>/`.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path A applies here too; backend projects are siblings of frontend projects under `source-code/`.

## Workflow

### 1. Selections

Ask the user each of the following, one section at a time, and record their answer. Present the default and a 1-line tradeoff for the alternatives - do not just dump a list.

**Project name and package manager:** Ask for the project name. Ask for the package manager: **pnpm** (default), npm, or yarn.

**Language:** TypeScript (default) or JavaScript. The choice drives the dev runner (next item) and the build step.

**Dev runner:** picks itself from the language choice - do not ask.

- **TS → `tsx watch`** (default). Fast, no separate build step for dev. Install: `tsx`.
- **JS → `nodemon`**. Watches files and restarts the process. Install: `nodemon`.

**Framework:** Express (fixed). No alternatives in this skill - swap only via explicit user override.

**Database:** PostgreSQL (default) or MongoDB.

**ORM / ODM:** choice depends on the DB:

- **PostgreSQL → Prisma** (default) or **Drizzle**. Prisma: generated client, migrations, DX-friendly. Drizzle: SQL-first, lighter runtime, closer to raw queries.
- **MongoDB → Mongoose**. No alternative in this skill - Mongoose is the mature default.

**Validation:** Zod (fixed). Request bodies, query params, and env vars all parse through Zod. No alternative in this skill.

**Logger:** pino (fixed). Structured JSON logs, pino-pretty for dev. No alternative in this skill.

**Env / config:** `dotenv` + a Zod schema in `src/config/env.ts` that `safeParse`s `process.env` at boot and throws on invalid values. No alternative.

**Security middleware (defaults on):** `helmet`, `cors`, `express-rate-limit`. Ask only if the user wants to disable one - otherwise install all three.

**Unit / integration testing:** Vitest + Supertest (default) or Jest + Supertest. Supertest hits the Express app in-process - no network, no port.

**Linter / formatter:** ESLint (flat config) + Prettier (default). Ask whether to add `eslint-plugin-import` for import ordering - if yes, pin **`eslint@^9`** (v10 breaks the plugin). For projects already on ESLint 10, use `eslint-plugin-import-x` instead.

**Optional add-ons:** ask only if the user brings them up - do not prompt by default.

- Redis cache (`ioredis`), BullMQ queue, Nodemailer / Resend mail, file uploads (`multer`), Docker Compose for the DB. Record each in `CLAUDE.md` under *Optional capabilities*.

### 2. Confirmation

Echo the full selection back as a bullet list and get explicit approval before running any install command.

### 3. Scaffold

**No official Express CLI.** `express-generator` is outdated (CommonJS, Jade, no TS). Scaffold manually - the layout below is small and the user sees every piece.

All commands run from `source-code/<name>/`. Commands use `pnpm` - for `npm` / `yarn` swap `pnpm add` → `npm i` / `yarn add` and `pnpm dlx` → `npx` / `yarn dlx`.

**Init:**

```bash
pnpm init
```

Edit `package.json`: set `"type": "module"` (ESM everywhere), set `"name"`.

**Core runtime:**

```bash
pnpm add express
pnpm add -D @types/express @types/node   # TS only
```

**Dev runner (from the language choice):**

```bash
# TS (default)
pnpm add -D tsx

# JS
pnpm add -D nodemon
```

**TypeScript (TS only):**

```bash
pnpm add -D typescript
pnpm exec tsc --init
```

Edit `tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src",
    "baseUrl": ".",
    "paths": { "@/*": ["src/*"] }
  },
  "include": ["src"]
}
```

Path alias `@/*` → `src/*`. Runtime resolution for TS at dev time: `tsx` reads `tsconfig.json` paths natively - no extra loader. For production (`node dist/index.js`), compile with `tsc` and either rely on Node's `--experimental-specifier-resolution=node` or add `tsc-alias` as a post-build step to rewrite paths:

```bash
pnpm add -D tsc-alias
```

**Database + ORM:**

- **PostgreSQL + Prisma (default):**
  ```bash
  pnpm add @prisma/client
  pnpm add -D prisma
  pnpm exec prisma init --datasource-provider postgresql
  ```
  Edit `.env` → `DATABASE_URL=postgresql://user:pass@localhost:5432/<name>`. Create `src/lib/prisma.ts` → `export const prisma = new PrismaClient()`. Run `pnpm exec prisma migrate dev --name init` after the first schema model is added (deferred to `be-boilerplate`).

- **PostgreSQL + Drizzle:**
  ```bash
  pnpm add drizzle-orm pg
  pnpm add -D drizzle-kit @types/pg
  ```
  Create `drizzle.config.ts` with the `pg` driver + `DATABASE_URL`. Create `src/db/index.ts` → `drizzle(new Pool({ connectionString: env.DATABASE_URL }))`. Migrations: `pnpm exec drizzle-kit generate` + `pnpm exec drizzle-kit migrate`.

- **MongoDB + Mongoose:**
  ```bash
  pnpm add mongoose
  ```
  Create `src/lib/mongo.ts` → `await mongoose.connect(env.MONGO_URL)` called once from `src/index.ts` before `app.listen`. Set `.env` → `MONGO_URL=mongodb://localhost:27017/<name>`.

**Validation + env:**

```bash
pnpm add zod dotenv
```

Create `src/config/env.ts`:

```ts
import 'dotenv/config'
import { z } from 'zod'

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(3000),
  DATABASE_URL: z.string().url(),   // or MONGO_URL for Mongo projects
})

const parsed = schema.safeParse(process.env)
if (!parsed.success) {
  console.error('Invalid environment:', parsed.error.flatten().fieldErrors)
  process.exit(1)
}
export const env = parsed.data
```

**Logger:**

```bash
pnpm add pino pino-http
pnpm add -D pino-pretty
```

Create `src/lib/logger.ts` → `export const logger = pino({ transport: env.NODE_ENV === 'development' ? { target: 'pino-pretty' } : undefined })`. Register `pinoHttp({ logger })` as the first middleware so every request logs structured.

**Security middleware:**

```bash
pnpm add helmet cors express-rate-limit
```

**Testing:**

- **Vitest + Supertest (default):**
  ```bash
  pnpm add -D vitest supertest @types/supertest
  ```
  Add `"test": "vitest"` to `package.json` scripts. In `vitest.config.ts`, resolve `@/*` via `vite-tsconfig-paths` (`pnpm add -D vite-tsconfig-paths`).

- **Jest + Supertest:**
  ```bash
  pnpm add -D jest @types/jest ts-jest supertest @types/supertest
  ```
  Add `"test": "jest"` script. Configure `ts-jest` preset + `moduleNameMapper` for `@/*`.

**Lint / format:**

```bash
pnpm add -D eslint@^9 prettier eslint-config-prettier eslint-plugin-prettier
```

If import ordering opted in: `pnpm add -D eslint-plugin-import` (swap for `eslint-plugin-import-x` on ESLint 10).

**Scripts** - add to `package.json`:

```json
{
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc && tsc-alias",
    "start": "node dist/index.js",
    "typecheck": "tsc --noEmit",
    "lint": "eslint .",
    "format": "prettier -w .",
    "test": "vitest",
    "db:migrate": "prisma migrate dev",
    "db:studio": "prisma studio"
  }
}
```

For JS projects, swap `dev` to `nodemon src/index.js`, drop `build` / `start` / `typecheck`. Drop the `db:*` scripts for Mongoose; for Drizzle, replace with `drizzle-kit` equivalents.

**Entry point** - `src/index.ts`:

```ts
import express from 'express'
import helmet from 'helmet'
import cors from 'cors'
import rateLimit from 'express-rate-limit'
import pinoHttp from 'pino-http'
import { env } from '@/config/env'
import { logger } from '@/lib/logger'
import { errorHandler } from '@/middleware/error-handler'

const app = express()
app.use(pinoHttp({ logger }))
app.use(helmet())
app.use(cors())
app.use(express.json())
app.use(rateLimit({ windowMs: 60_000, max: 100 }))

app.get('/health', (_req, res) => res.json({ status: 'ok' }))

app.use(errorHandler)   // last

app.listen(env.PORT, () => logger.info(`listening on :${env.PORT}`))
```

**Response envelope + error registry** - follow `.claude/rules/be-response.md`. Emit six files; the error middleware is wired last in `src/index.ts`.

```text
src/types/response.ts              # SuccessResponse, ErrorResponse, Meta, Pagination
src/constants/error-codes.ts       # ERROR_CODES as const, ErrorCode type
src/constants/error-messages.ts    # ERROR_MESSAGES: Record<ErrorCode, { message, httpStatus }>
src/lib/app-error.ts               # AppError(code, detail?, overrideMessage?)
src/lib/response.ts                # sendOk, sendCreated, buildPagination
src/middleware/error-handler.ts    # AppError | ZodError | unknown → envelope
```

`src/middleware/error-handler.ts`:

```ts
import type { ErrorRequestHandler } from 'express'
import { ZodError } from 'zod'
import { ERROR_CODES } from '@/constants/error-codes'
import { ERROR_MESSAGES } from '@/constants/error-messages'
import { AppError } from '@/lib/app-error'
import { logger } from '@/lib/logger'

export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (err instanceof ZodError) {
    const spec = ERROR_MESSAGES[ERROR_CODES.VALIDATION_FAILED]
    return res.status(spec.httpStatus).json({
      status: 'error',
      error: { code: ERROR_CODES.VALIDATION_FAILED, message: spec.message, detail: err.flatten() },
    })
  }
  if (err instanceof AppError) {
    return res.status(err.httpStatus).json({
      status: 'error',
      error: { code: err.code, message: err.message, detail: err.detail },
    })
  }
  logger.error({ err }, 'unhandled error')
  const spec = ERROR_MESSAGES[ERROR_CODES.INTERNAL_ERROR]
  res.status(spec.httpStatus).json({
    status: 'error',
    error: { code: ERROR_CODES.INTERNAL_ERROR, message: spec.message },
  })
}
```

Field shapes, helper signatures, and the sensitive-field MUST rule all live in the shared rule - don't restate here.

**Folder layout** - create empty folders now; files land as features arrive:

```text
src/
├── config/          # env.ts (Zod-parsed process.env)
├── constants/       # error-codes.ts, error-messages.ts
├── routes/          # route definitions (one file per resource)
├── controllers/     # thin HTTP handlers - parse req, call service, send res
├── services/        # business logic - no req/res
├── repositories/    # DB access (Prisma/Drizzle/Mongoose) - no HTTP
├── schemas/         # Zod request/response schemas
├── middleware/      # error-handler.ts, auth.ts (added by be-auth)
├── lib/             # app-error.ts, response.ts, prisma.ts | mongo.ts, logger.ts
├── types/           # response.ts envelope types + ambient .d.ts
└── index.ts         # bootstrap
```

Once install completes, run [Verification](#verification) before moving on.

### 4. Boilerplate routes *(optional)*

Ask first: "Scaffold starter routes?" Invoke `be-boilerplate` to scaffold a sample resource (CRUD for one entity), a health route, and auth route stubs under `src/stubs/auth/`.

### 5. Authentication decision *(optional)*

Ask: "Wire authentication now, or defer?" Auth is **optional at setup time** - you can skip it and invoke `be-auth` later.

- If **now** → invoke `be-auth` to wire JWT access + refresh, argon2 password hashing, `src/middleware/auth.ts`, and the `/auth/login`, `/auth/refresh`, `/auth/logout` routes. If step 4 emitted stubs, `be-auth` swaps them for the real handlers and deletes `src/stubs/auth/`.
- If **deferred** → note "auth deferred; run `be-auth` when needed" in `CLAUDE.md`. Stubs from step 4 stay in place.

### 6. CLAUDE.md

Create `CLAUDE.md` at project root capturing:

- Selections from step 1 - project name, PM, language, DB, ORM, validation (Zod), logger (pino), env strategy, security middleware status, unit test, lint.
- Path alias rule (`@/*` → `src/*`), folder layout.
- Dev / build / start scripts.
- Auth status (wired now / deferred, link to `be-auth`).
- Optional capabilities - one line each when enabled: `redis: ioredis`, `queue: bullmq`, `mail: nodemailer`, `uploads: multer`, `docker-compose: db only`. Omit the line when the capability is off.
- Don'ts.

## Input

- None (greenfield).

## Output

- New project skeleton under `source-code/<name>/`.
- `tsconfig.json` with `@/*` alias (TS only), `package.json` scripts.
- ESLint + Prettier configs.
- `src/index.ts`, `src/config/env.ts`, `src/lib/logger.ts`, `src/middleware/error-handler.ts`, DB client in `src/lib/` or `src/db/`.
- `.env` + `.env.example` with the DB URL slot.
- `CLAUDE.md` at project root.
- (Optional, via `be-boilerplate` then `be-auth`) sample resource, auth routes.

## Verification

Run in order from `source-code/<name>/` - stop and fix on first failure.

```bash
pnpm dev             # server boots, logs "listening on :3000"
curl localhost:3000/health   # → {"status":"ok"}
pnpm typecheck       # TS only
pnpm lint
pnpm test -- --run   # if Vitest is wired
pnpm build           # TS only - produces dist/
pnpm start           # TS only - runs compiled output
```

- `pwd` ends with `source-code/<name>` (not the repo root, not a sibling).
- `@/*` alias resolves in both `src/` and tests (import `@/config/env` from a test).
- `.env` is `.gitignore`d; `.env.example` is committed.
- `CLAUDE.md` exists at project root with selections + auth status recorded.
