---
name: be-boilerplate
description: Use after be-setup to scaffold starter routes. Offers three combinable options - a sample CRUD resource, OpenAPI docs, or a user-described custom resource. Auth routes are scaffolded as stubs unless be-auth already ran; be-auth swaps them for the real handlers later.
---

# be-boilerplate

Assumes `be-setup` has picked language / DB / ORM. Runs **before** `be-auth` in the `be-setup` flow - auth routes are scaffolded as stubs by default. Only when `be-auth` has already wired its handlers (standalone re-run) are they real.

## Contents

**Setup** - preconditions and shared rules.
- [Prerequisites](#prerequisites) - upstream skills, deps.
- [Working directory](#working-directory) - target project under `source-code/`.
- [Shared conventions](#shared-conventions) - project structure, coding, state rules.

**Workflow** - what to scaffold and in what order.
- [0. API conventions](#0-api-conventions-before-any-route) - error envelope, success shape, pagination, validation pattern.
- [1. Choose starter(s)](#1-choose-starters) - sample resource / custom / OpenAPI, auth stubs auto-detected.
- [2. Health route](#2-health-route-always-emit) - `/health`, deep check optional.
- [3. Sample resource](#3-sample-resource) - full CRUD slice for one entity.
- [4. OpenAPI docs](#4-openapi-docs-optional) - Swagger UI mounted at `/docs`.
- [5. Custom resource](#5-custom-resource) - user-described entity + endpoints.
- [6. App factory](#6-app-factory) - split `createApp()` from the listener so `be-test` can import without binding a port.
- [7. Hand off to be-test](#7-hand-off-to-be-test) - tests and Postman live there.

**Auth handling** - stubbed default, real path when `be-auth` already ran.
- [Auth stubs](#auth-stubs-default) - fixture handlers under `src/stubs/auth/`, swapped by `be-auth`.
- [Auth middleware](#auth-middleware-when-be-auth-already-ran) - `requireAuth` applied to protected routes.

**Conventions** - request / response shape.
- [Validation convention](#validation-convention) - Zod at the controller edge, parsed values flow down.
- [Routes wiring](#routes-wiring) - router per resource, mounted in `src/index.ts`.

**I/O & verification** - closing loop.
- [Input](#input) - `be-setup` selections, optional `be-auth` handlers.
- [Output](#output) - starter routes, schemas, repository, stubs.
- [Verification](#verification) - typecheck, lint, test, curl sweep.

## Prerequisites

- **`be-setup` has run** - project scaffolded at `source-code/<project-name>/` with `CLAUDE.md` capturing language, DB, ORM, validation (Zod), logger (pino), and auth status.
- **Database reachable** - the sample resource runs real migrations and a sample insert. For Prisma / Drizzle, `DATABASE_URL` must resolve. For Mongoose, `MONGO_URL` must resolve.

## Working directory

Runs inside `source-code/<project-name>/` - the project scaffolded by `be-setup`. Before scaffolding routes: confirm the current directory, read that project's `CLAUDE.md` for DB / ORM / auth status, and if multiple projects exist under `source-code/`, ask which one first. All generated files (`src/routes/…`, `src/controllers/…`, `src/stubs/auth/…`) go under that project only.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B (inside an existing project).

## Shared conventions

- **Project structure:** layered - `routes → controllers → services → repositories → schemas` + `middleware/`, `lib/`, `config/`, `types/`. One folder per layer at `src/`, one file per entity inside each layer.
- **Coding conventions:** `.claude/rules/be-coding-conventions.md` - naming, imports, TS rules, layer map, controller / service / repository / schema invariants.
- **Error handling:** controller catches nothing - throws `AppError` or lets Zod throw; `src/middleware/error-handler.ts` (from `be-setup`) owns the response envelope.
- **Logger:** every request already logs via `pino-http` (wired in `be-setup`). Do not re-log happy paths.

## 0. API conventions *(before any route)*

Response shape, error registry, pagination, and sensitive-field MUST rules live in `.claude/rules/be-response.md`. Load it once per session. Every scaffolded controller + service follows it; the files (`src/types/response.ts`, `src/constants/error-codes.ts`, `src/constants/error-messages.ts`, `src/lib/app-error.ts`, `src/lib/response.ts`, `src/middleware/error-handler.ts`) are emitted by `be-setup`.

Shorthand for this skill:

- **Controllers** parse (Zod) → call service → `sendOk(res, data, meta?)` / `sendCreated(res, data, meta?)` from `@/lib/response`. Never hand-build `{ status: 'success', ... }`. Never `try/catch`.
- **Services** throw `new AppError(ERROR_CODES.X, detail?)` from `@/lib/app-error`. New failure mode → add a code to `src/constants/error-codes.ts` + a row to `src/constants/error-messages.ts`.
- **List** controllers return `data: items` + `meta: { pagination: buildPagination(page, pageSize, total) }`. Service returns `{ items, total }`.
- **IDs** - the ORM default. Prisma: `cuid()`. Drizzle: `uuid v4`. Mongoose: `ObjectId` serialized as a string.
- **Timestamps** - `createdAt` / `updatedAt`, ISO 8601 strings. Prisma / Drizzle: `@default(now())` + `@updatedAt`. Mongoose: `{ timestamps: true }`.
- **Sensitive fields** - `password` / `passwordHash` / `tokenHash` / `resetTokenHash` **MUST NOT** appear in any response body. Enforce at the ORM layer (Prisma `omit`, Drizzle explicit `select`, Mongoose projection) - every repo method that returns a user / token-bearing entity scopes the hash out, except the single login path that verifies it.

Record "Response envelope: see `.claude/rules/be-response.md`" under *API conventions* in `CLAUDE.md` and move on.

## 1. Choose starter(s)

Ask the user which starter(s) to scaffold. **Options are combinable** (e.g., sample resource + OpenAPI):

- **Sample resource** (default) - full CRUD for a `users` entity so the user sees the layered flow end-to-end.
- **OpenAPI docs** - mounts Swagger UI at `/docs` from JSDoc / schema annotations.
- **Custom** - user describes one or more entities + endpoints; scaffold the same layered slice per entity.

Do not ask about auth. Detect it: if `src/middleware/auth.ts` already exists from `be-auth`, protected routes get `requireAuth`; otherwise auth routes are scaffolded as stubs under `src/stubs/auth/` and no protection is applied. `be-auth` replaces the stubs afterwards.

## 2. Health route *(always emit)*

`GET /health` is already in `src/index.ts` from `be-setup` returning `{ status: 'ok' }`. If the user wants a **deep check**, emit `GET /health/ready` that also pings the DB:

```ts
// src/routes/health.ts
app.get('/health/ready', async (_req, res) => {
  await prisma.$queryRaw`SELECT 1`   // or: await mongoose.connection.db.admin().ping()
  res.json({ status: 'ready', db: 'ok' })
})
```

Deep check throws → `error-handler` returns 500 with `{ error: 'NotReady' }`. Load balancers hit `/health` (shallow); orchestrators hit `/health/ready` (deep).

## 3. Sample resource

Scaffold a full CRUD slice for one entity (`user` by default - rename if the user asks). Files land in the layered map:

```text
src/schemas/user.ts         ← Zod schema + inferred type
src/repositories/user.ts    ← DB access (Prisma / Drizzle / Mongoose)
src/services/user.ts        ← Business logic - no req/res
src/controllers/user.ts     ← HTTP: parse → call service → send
src/routes/user.ts          ← Express Router, mounts controller
```

**Schema** - `src/schemas/user.ts`:

```ts
import { z } from 'zod'

export const userCreateSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(80),
})
export const userUpdateSchema = userCreateSchema.partial()
export const userIdParam = z.object({ id: z.string().min(1) })
export const userListQuery = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
  q: z.string().optional(),
})

export type UserCreate = z.infer<typeof userCreateSchema>
export type UserUpdate = z.infer<typeof userUpdateSchema>
```

**Repository** - `src/repositories/user.ts` (Prisma example; Drizzle / Mongoose variants follow the same signatures):

```ts
import { prisma } from '@/lib/prisma'
import type { UserCreate, UserUpdate } from '@/schemas/user'

export const userRepo = {
  list: ({ page, pageSize, q }: { page: number; pageSize: number; q?: string }) =>
    prisma.$transaction([
      prisma.user.findMany({
        where: q ? { OR: [{ email: { contains: q } }, { name: { contains: q } }] } : undefined,
        skip: (page - 1) * pageSize,
        take: pageSize,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.user.count({ where: q ? { OR: [{ email: { contains: q } }, { name: { contains: q } }] } : undefined }),
    ]),
  byId: (id: string) => prisma.user.findUnique({ where: { id } }),
  create: (data: UserCreate) => prisma.user.create({ data }),
  update: (id: string, data: UserUpdate) => prisma.user.update({ where: { id }, data }),
  remove: (id: string) => prisma.user.delete({ where: { id } }),
}
```

**Service** - `src/services/user.ts`:

```ts
import { ERROR_CODES } from '@/constants/error-codes'
import { AppError } from '@/lib/app-error'
import { userRepo } from '@/repositories/user'
import type { UserCreate, UserUpdate } from '@/schemas/user'

export const userService = {
  list: async (q: { page: number; pageSize: number; q?: string }) => {
    const [items, total] = await userRepo.list(q)
    return { items, total }
  },
  get: async (id: string) => {
    const user = await userRepo.byId(id)
    if (!user) throw new AppError(ERROR_CODES.NOT_FOUND)
    return user
  },
  create: (data: UserCreate) => userRepo.create(data),
  update: (id: string, data: UserUpdate) => userRepo.update(id, data),
  remove: (id: string) => userRepo.remove(id),
}
```

**Controller** - `src/controllers/user.ts`:

```ts
import type { Request, Response } from 'express'
import { buildPagination, sendCreated, sendOk } from '@/lib/response'
import { userCreateSchema, userUpdateSchema, userIdParam, userListQuery } from '@/schemas/user'
import { userService } from '@/services/user'

export const userController = {
  list: async (req: Request, res: Response) => {
    const query = userListQuery.parse(req.query)
    const { items, total } = await userService.list(query)
    sendOk(res, items, { pagination: buildPagination(query.page, query.pageSize, total) })
  },
  get: async (req: Request, res: Response) => {
    const { id } = userIdParam.parse(req.params)
    sendOk(res, await userService.get(id))
  },
  create: async (req: Request, res: Response) => {
    const body = userCreateSchema.parse(req.body)
    sendCreated(res, await userService.create(body))
  },
  update: async (req: Request, res: Response) => {
    const { id } = userIdParam.parse(req.params)
    const body = userUpdateSchema.parse(req.body)
    sendOk(res, await userService.update(id, body))
  },
  remove: async (req: Request, res: Response) => {
    const { id } = userIdParam.parse(req.params)
    await userService.remove(id)
    res.status(204).send()
  },
}
```

**Router** - `src/routes/user.ts`:

```ts
import { Router } from 'express'
import { userController } from '@/controllers/user'
import { requireAuth } from '@/middleware/auth'   // real if be-auth ran; stub re-export otherwise

export const userRouter = Router()
userRouter.get('/', requireAuth, userController.list)
userRouter.get('/:id', requireAuth, userController.get)
userRouter.post('/', requireAuth, userController.create)
userRouter.patch('/:id', requireAuth, userController.update)
userRouter.delete('/:id', requireAuth, userController.remove)
```

**Mount** in `src/index.ts` (after existing middleware, before `errorHandler`):

```ts
import { userRouter } from '@/routes/user'
app.use('/users', userRouter)
```

**Async controllers must forward thrown errors.** Express 5 propagates thrown promise rejections automatically. On Express 4, wrap each controller in a tiny `asyncHandler` or use `express-async-errors` (install once in `src/index.ts` top import). Check the installed version with `pnpm why express`; emit the helper only if `^4`.

**ORM model** - add the entity to the ORM schema and run the migration before the router is mountable:

- **Prisma:** append `model User { id String @id @default(cuid()) email String @unique name String createdAt DateTime @default(now()) updatedAt DateTime @updatedAt }` to `prisma/schema.prisma`, then `pnpm exec prisma migrate dev --name init-user`.
- **Drizzle:** add the table in `src/db/schema.ts`, then `pnpm exec drizzle-kit generate && pnpm exec drizzle-kit migrate`.
- **Mongoose:** `src/repositories/user.ts` defines a `Schema` + `model('User', …)` directly - no migration step.

## 4. OpenAPI docs *(optional)*

Only if the user asked. Install:

```bash
pnpm add swagger-ui-express
pnpm add -D @types/swagger-ui-express
```

Pick a spec source:

- **JSDoc-driven (default)** - `pnpm add -D swagger-jsdoc @types/swagger-jsdoc`. Scan `src/routes/**/*.ts` for `@openapi` JSDoc blocks on each route and merge into an OpenAPI 3 document.
- **Zod-driven** - `pnpm add zod-to-openapi`. Reuses the existing Zod schemas from `src/schemas/` so request shapes stay in sync by construction. Preferred when the project will keep adding resources.

Mount at `/docs`:

```ts
import swaggerUi from 'swagger-ui-express'
import { openApiSpec } from '@/lib/openapi'
app.use('/docs', swaggerUi.serve, swaggerUi.setup(openApiSpec))
```

Gate `/docs` behind `env.NODE_ENV !== 'production'` **or** `requireAuth` - never publish the full API surface anonymously in prod.

## 5. Custom resource

Ask the user:

1. Entity name (singular + plural) and the fields with types.
2. Which endpoints to expose (list / get / create / update / delete - subset is fine).
3. Whether the entity is protected (`requireAuth`) or public.
4. Any filters / sort / search semantics for `list`.

Scaffold the same five-file slice as [Sample resource](#3-sample-resource), substituting the entity. If the entity has relationships (`post belongsTo user`), ask whether to include the FK + joined read in `list` / `get` (default yes, keyed off the ORM).

## 6. App factory

Split the Express app from the listener so `be-test` (and any future Supertest-based skill) can import the app without binding a port. Replace the single `src/index.ts` from `be-setup` with two files:

```ts
// src/app.ts
import cookieParser from 'cookie-parser'
import cors from 'cors'
import express from 'express'
import helmet from 'helmet'
import pinoHttp from 'pino-http'

import { logger } from '@/lib/logger'
import { errorHandler } from '@/middleware/error-handler'
import { authRouter } from '@/routes/auth'
import { healthRouter } from '@/routes/health'
import { userRouter } from '@/routes/user'

export const createApp = () => {
  const app = express()
  app.use(pinoHttp({ logger }))
  app.use(helmet())
  app.use(cors())
  app.use(express.json())
  app.use(cookieParser())

  app.use('/auth', authRouter)
  app.use('/health', healthRouter)
  app.use('/users', userRouter)

  app.use(errorHandler)
  return app
}
```

```ts
// src/index.ts
import { createApp } from '@/app'
import { env } from '@/config/env'
import { logger } from '@/lib/logger'

createApp().listen(env.PORT, () => logger.info(`listening on :${env.PORT}`))
```

Rate limiting is **not** mounted here - that is `be-rate-limit`'s job. The factory stays middleware-light so each later skill owns its own wiring without conflict.

## 7. Hand off to be-test

Unit tests, route-level smokes, the `__tests__/` layout, the `tsconfig.test.json` split, the `postgres-test` compose service, the pino level-gate, and the optional Postman collection all live in **`be-test`**. Run it next:

```text
Boilerplate finished. Run `be-test` to add the test harness + unit tests, then (optionally)
`be-auth` to replace the stub auth router with real JWT handlers.
```

Do not scaffold tests from this skill - everything test-related is owned by `be-test`.

## Auth stubs *(default)*

Location: `src/stubs/auth/` - one folder for all stub pieces so they can be deleted together.

- `src/stubs/auth/users.json` - fixture users (seeded with `demo@example.com` / `password`).
- `src/stubs/auth/handlers.ts` - fake `stubLogin`, `stubRegister`, `stubRefresh`, `stubLogout` that resolve after a short delay and return a fake JWT (`'stub.' + base64(email)`).
- `src/stubs/auth/routes.ts` - Express Router mounting `POST /login`, `POST /register`, `POST /refresh`, `POST /logout` to the fake handlers.
- `src/stubs/auth/require-auth.ts` - stub middleware that accepts any `Authorization: Bearer stub.*` header, attaches `req.user = { id: 'stub-user', email: '…' }`.
- `src/middleware/auth.ts` - **re-exports** `requireAuth` from the stub module so `src/routes/*.ts` imports stay stable:

  ```ts
  // src/middleware/auth.ts (stub-era)
  export { stubRequireAuth as requireAuth } from '@/stubs/auth/require-auth'
  ```

The stub router mounts in `src/index.ts`:

```ts
import { stubAuthRouter } from '@/stubs/auth/routes'
app.use('/auth', stubAuthRouter)
```

When `be-auth` runs later, it swaps `src/middleware/auth.ts` for the real implementation, replaces the mounted router, and deletes `src/stubs/auth/` - see its stub → real swap checklist.

## Auth middleware *(when be-auth already ran)*

`src/middleware/auth.ts` is a real `requireAuth` that verifies the JWT, attaches `req.user`, and 401s on failure. The sample / custom routers import it as above - no further wiring needed from this skill.

## Validation convention

- **Parse at the controller edge, once per request** - never in the service or repository. Services receive typed, validated input.
- **One schema file per entity** at `src/schemas/<entity>.ts` - request bodies, query params, path params, and inferred TS types all co-live.
- **Never re-derive schemas inside a controller body** - hoist to module scope (see `.claude/rules/be-coding-conventions.md` anti-patterns).
- **Zod errors flow to the error handler** - do not `try/catch` them in the controller; `error-handler.ts` already maps `ZodError → 400 VALIDATION_FAILED` with `detail = flatten()`.

## Routes wiring

Each entity ships one Router mounted at `/<plural>` in `src/index.ts`. Keep the mount section tight and alphabetized:

```ts
app.use('/auth', authRouter)     // stub or real
app.use('/users', userRouter)
app.use('/posts', postRouter)
```

If the project grows past ~6 routers, promote to `src/routes/index.ts` that re-exports a `mountRoutes(app)` function - do not inline more than six `app.use` lines in `index.ts`.

## Input

- `be-setup` selections (language, DB, ORM, auth status).
- `be-auth` middleware + handlers (optional - only present on a standalone re-run after auth).

## Output

- Chosen starter(s): sample `users` resource and/or user-described custom resources.
- `GET /health/ready` (if deep check requested).
- OpenAPI docs at `/docs` (if requested) - JSDoc or Zod-driven.
- Default: stub auth router + fixture handlers + stub `requireAuth` under `src/stubs/auth/`.
- If `be-auth` already ran: routers import the real `requireAuth`; no stubs emitted.
- ORM schema entries + first migration for each scaffolded entity.
- `src/app.ts` factory + `src/index.ts` listener (split per §6).

Not emitted by this skill: unit tests, route-level smokes, `tsconfig.test.json`, `postgres-test` compose service, Postman collection - all owned by `be-test`.

## Verification

Run from `source-code/<project-name>/`. Stop and fix on first failure.

```bash
pnpm typecheck
pnpm lint
pnpm dev              # server boots

curl -s localhost:3000/health | jq
curl -s -X POST localhost:3000/users -H 'content-type: application/json' -d '{"email":"a@b.com","name":"A"}' | jq
curl -s localhost:3000/users | jq
```

- `pnpm exec prisma migrate status` (or ORM equivalent) is clean - the sample entity's migration applied.
- Every mounted router responds to its happy-path verb with the shared envelope (list → `{ status: 'success', data: [...], meta: { pagination } }`; create → `{ status: 'success', data: entity }` at 201; delete → 204 no body).
- Invalid body returns `400 { status: 'error', error: { code: 'VALIDATION_FAILED', detail: ... } }` - verify by posting an empty object.
- Protected routes return `401 { status: 'error', error: { code: 'AUTH_UNAUTHORIZED' } }` without a token. With the stub `Authorization: Bearer stub.<base64>` header, they succeed.
- If auth was stubbed: `src/stubs/auth/` exists; `src/middleware/auth.ts` re-exports the stub. After `be-auth` runs, grep sweep:

  ```bash
  rg -n 'stubs/auth' src
  ```

  Zero results means real auth has fully replaced the stubs.
