---
name: be-rate-limit
description: Use when adding or extending rate limiting on a Node.js backend under source-code/<name>-be/. Walks through global / per-user / auth-sensitive limiter choices, scaffolds a shared `createLimiter` factory with `express-rate-limit`, and offers Redis (default) or in-memory as the store. Also integrates `RATE_LIMITED` into the error envelope so 429s flow through the standard error pipeline.
---

# be-rate-limit

Default: **Redis-backed limiters, in-memory fallback for `NODE_ENV=test`.** One shared factory in `src/middleware/rate-limit.ts`; auth-sensitive limiters are opt-in; window / limit values have sensible defaults the user can override.

## Contents

**Setup** - preconditions and target.
- [Prerequisites](#prerequisites) - project state, store choice.
- [Working directory](#working-directory) - must be `source-code/<name>-be/`.

**Workflow** - selections → confirm → scaffold → wire.
- [1. Selections](#1-selections) - global on/off, per-user on/off, auth-sensitive opt-in, store, defaults.
- [2. Confirmation](#2-confirmation) - echo the picks before writing.
- [3. Store scaffold](#3-store-scaffold) - Redis client + `.env` + docker-compose, or in-memory no-op.
- [4. Error registry](#4-error-registry) - add `RATE_LIMITED` + 429 to `error-codes` + `error-messages`.
- [5. Factory + limiters](#5-factory--limiters) - `createLimiter`, `globalLimiter`, `perUserLimiter`.
- [6. Wire into app.ts](#6-wire-into-appts) - global before routes; per-user after `requireAuth`.
- [7. Auth-sensitive limiters](#7-auth-sensitive-limiters-optional) - `loginLimiter`, `forgotPasswordLimiter`.
- [8. CLAUDE.md](#8-claudemd) - record the stack entry + the rate-limit section.

**I/O & verification**
- [Input](#input) - existing `be-setup` + `be-boilerplate` output.
- [Output](#output) - files written.
- [Verification](#verification) - typecheck, test, hit a route 101 times.

**Anti-patterns**
- [Anti-patterns - reject on sight](#anti-patterns---reject-on-sight)

## Prerequisites

- The project was scaffolded by `be-setup` (Express + Zod + Prisma + Pino + `AppError` envelope).
- `src/constants/error-codes.ts` + `src/constants/error-messages.ts` already exist (part of `be-setup`).
- If choosing **Redis** store: Docker available (default local store runs via docker-compose) **or** an external Redis URL (Upstash, Redis Cloud, managed KV).

## Working directory

Must be `source-code/<project-name>-be/`. Confirm by:

```bash
pwd                        # must end in source-code/<name>-be
ls CLAUDE.md src/app.ts    # both must exist
```

If either fails, stop - the project was not scaffolded by `be-setup`.

## 1. Selections

Ask each question. Suggested defaults in **bold**.

- **Global limiter** - mounted before any route, keyed by IP.
  - Enable? **yes**
  - `windowMs` default: **15 min**
  - `limit` default: **100 req / window / IP**
- **Per-user limiter** - keyed by `req.user.sub` after `requireAuth`, falls back to IP for anonymous callers.
  - Enable? **yes**
  - `windowMs` default: **1 min**
  - `limit` default: **30 req / window / user**
  - Scope: default is **do not auto-mount**; expose it as a middleware the user wires onto hot routes (e.g. search, exports). If the user wants it auto-mounted on every authenticated route, offer a one-liner inside each router.
- **Auth-sensitive limiters** - stricter limits on `/auth/login` and `/auth/forgot-password`.
  - Enable? **optional** (default **no** for new projects; the user can add them later via one call to `createLimiter`).
  - Suggested if enabled: `login` → 15 min / 5 req / IP; `forgot-password` → 1 hr / 3 req / IP.
- **Store**:
  - **Redis (default)** - correct across multiple Node instances and serverless deploys.
    - Local: adds a `redis:7-alpine` service to `docker-compose.yml`, `REDIS_URL=redis://localhost:6379` default.
    - Remote: user pastes a `REDIS_URL` (Upstash, Vercel KV, Redis Cloud); no docker-compose change.
  - **In-memory** - zero-config, correct on a single long-running Node process only. Pick this only if the user confirms single-instance deploy and no horizontal scaling.

**Store default rule**: if the project's `CLAUDE.md` already lists Redis under *Stack*, reuse the existing `@/lib/redis` client. Otherwise scaffold a new one in step 3.

## 2. Confirmation

Echo the picks in one block and get a yes/no before writing:

```text
Rate limiting:
- Global:        on   15 min / 100 req / IP
- Per-user:      on   1 min / 30 req / user   (not auto-mounted)
- Auth-sensitive: off (can be added later)
- Store:         Redis (local docker-compose)
Proceed? (y/n)
```

If any limiter is disabled, do not emit its code.

## 3. Store scaffold

**Redis path.**

1. If Redis isn't in the project yet:
   - `pnpm add redis rate-limit-redis --save-exact`.
   - Add service to `docker-compose.yml` (`redis:7-alpine`, port `6379`, `appendonly yes`, volume `redis-data`, healthcheck).
   - Add `REDIS_URL` to `.env.example` and to `src/config/env.ts` as `z.string().url().default('redis://localhost:6379')`.
   - Write `src/lib/redis.ts`:

     ```ts
     import { createClient } from 'redis'

     import { env } from '@/config/env'
     import { logger } from '@/lib/logger'

     export const redis = createClient({ url: env.REDIS_URL })
     redis.on('error', (err) => logger.error({ err }, 'redis client error'))

     let connectPromise: Promise<unknown> | null = null

     export const connectRedis = () => {
       if (!connectPromise) {
         connectPromise = redis.connect().catch((err) => {
           connectPromise = null
           throw err
         })
       }
       return connectPromise
     }
     ```

     The cached promise is required: `express-rate-limit` kicks off `store.init()` as a microtask the moment a limiter is constructed, so `sendCommand` fires before `src/index.ts` reaches its `await connectRedis()`. Both callers share one `connect()` call - a plain `if (!isOpen) connect()` races and throws `ClientClosedError`.

   - In `src/index.ts`, `await connectRedis()` before `app.listen`.

2. If Redis already exists: skip install + file writes, reuse `@/lib/redis`.

**In-memory path.** Skip entirely. `express-rate-limit`'s default store is in-memory.

## 4. Error registry

Add one entry per registry file:

```ts
// src/constants/error-codes.ts
RATE_LIMITED: 'RATE_LIMITED',

// src/constants/error-messages.ts
[ERROR_CODES.RATE_LIMITED]: {
  message: 'Too many requests. Please try again later.',
  httpStatus: 429,
},
```

The existing error middleware already maps `AppError` → envelope - no middleware change needed.

## 5. Factory + limiters

Write `src/middleware/rate-limit.ts`:

```ts
import type { RequestHandler } from 'express'
import { ipKeyGenerator, rateLimit, type Options, type Store } from 'express-rate-limit'
import { RedisStore } from 'rate-limit-redis'

import { env } from '@/config/env'
import { ERROR_CODES } from '@/constants/error-codes'
import { AppError } from '@/lib/app-error'
import { connectRedis, redis } from '@/lib/redis'

const buildStore = (prefix: string): Store | undefined => {
  if (env.NODE_ENV === 'test') return undefined
  return new RedisStore({
    prefix: `rl:${prefix}:`,
    sendCommand: async (...args: string[]) => {
      await connectRedis()
      return redis.sendCommand(args) as Promise<never>
    },
  })
}

const rateLimitHandler: Options['handler'] = (_req, _res, next) => {
  next(new AppError(ERROR_CODES.RATE_LIMITED))
}

type BuildOpts = {
  prefix: string
  windowMs: number
  limit: number
  keyGenerator?: Options['keyGenerator']
}

export const createLimiter = ({ prefix, windowMs, limit, keyGenerator }: BuildOpts): RequestHandler =>
  rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    store: buildStore(prefix),
    keyGenerator,
    handler: rateLimitHandler,
  })

export const globalLimiter = createLimiter({
  prefix: 'global',
  windowMs: 15 * 60 * 1000,
  limit: 100,
})

export const perUserLimiter = createLimiter({
  prefix: 'user',
  windowMs: 60 * 1000,
  limit: 30,
  keyGenerator: (req) => req.user?.sub ?? ipKeyGenerator(req.ip ?? ''),
})
```

Key points:

- `env.NODE_ENV === 'test'` → in-memory store so unit tests never need Redis.
- Each limiter has its own `prefix` so counters never collide.
- `standardHeaders: 'draft-7'` emits `RateLimit-*` headers; `legacyHeaders: false` drops the deprecated `X-RateLimit-*`.
- Handler delegates to the global error middleware via `AppError(RATE_LIMITED)` - no custom response shape here.

## 6. Wire into app.ts

```ts
// src/app.ts
import { globalLimiter } from '@/middleware/rate-limit'
// ...
app.use(express.json())
app.use(cookieParser())
app.use(globalLimiter)   // global, keyed by IP, before any route

app.use('/auth', authRouter)
// ...
```

**Order rule.** `globalLimiter` goes **after** body parsers and **before** routes. `perUserLimiter` is attached per route, **after** `requireAuth` so `req.user.sub` is populated:

```ts
userRouter.get('/', requireAuth, perUserLimiter, userController.list)
```

Do not call it before `requireAuth` - the fallback keys on IP, which hides every authenticated caller behind one bucket for shared-NAT users.

## 7. Auth-sensitive limiters *(optional)*

Only if the user opted in. Write `src/middleware/auth-rate-limit.ts`:

```ts
import { createLimiter } from '@/middleware/rate-limit'

export const loginLimiter = createLimiter({
  prefix: 'auth-login',
  windowMs: 15 * 60 * 1000,
  limit: 5,
})

export const forgotPasswordLimiter = createLimiter({
  prefix: 'auth-forgot',
  windowMs: 60 * 60 * 1000,
  limit: 3,
})
```

Then in `src/routes/auth.ts`:

```ts
authRouter.post('/login', loginLimiter, authController.login)
authRouter.post('/forgot-password', forgotPasswordLimiter, authController.forgotPassword)
```

## 8. CLAUDE.md

Append to the project's `CLAUDE.md`:

- Under **Stack**: `Cache / rate-limit store: Redis via Docker Compose` (if Redis scaffolded).
- Under **Security middleware**: `express-rate-limit (Redis-backed via rate-limit-redis)`.
- Add a new **Rate limiting** section documenting `globalLimiter`, `perUserLimiter`, and `createLimiter`, plus the test-time in-memory fallback and the `AppError(RATE_LIMITED)` → `429` envelope flow.

## Input

- Existing `be-setup` + `be-boilerplate` output (Express app, Zod schemas, error envelope, Prisma).
- User answers to the selections in step 1.

## Output

Files written / modified:

- `src/middleware/rate-limit.ts` *(new)*
- `src/middleware/auth-rate-limit.ts` *(optional, new)*
- `src/constants/error-codes.ts` + `src/constants/error-messages.ts` *(one line each)*
- `src/app.ts` *(mount `globalLimiter`)*
- `src/lib/redis.ts` *(new if Redis was not already present)*
- `src/index.ts` *(await `connectRedis()` if Redis was added)*
- `src/config/env.ts` + `.env.example` *(`REDIS_URL` entry if Redis was added)*
- `docker-compose.yml` *(redis service if Redis was added)*
- `CLAUDE.md` *(stack + rate-limit section)*

## Verification

- `pnpm typecheck` passes.
- `pnpm test` passes (unit tests fall back to in-memory, no Redis required).
- With Redis up: hit any route 101 times from the same IP in 15 min → the 101st response is `429` with `{ status: 'error', error: { code: 'RATE_LIMITED', message: 'Too many requests. Please try again later.' } }` and `RateLimit-*` headers.
- After `requireAuth`, hit a `perUserLimiter`-gated route 31 times in a minute as the same user → the 31st response is `429`.

## Anti-patterns - reject on sight

- Hand-building the 429 body (`res.status(429).json({ error: 'TooManyRequests' })`) - throw `AppError(RATE_LIMITED)` and let the envelope middleware emit it.
- One `rateLimit({ ... })` repeated inline across routes - use `createLimiter` so prefixes, store, and handler stay consistent.
- Reusing the same `prefix` across unrelated limiters - counters collide, limits bleed.
- `perUserLimiter` mounted before `requireAuth` - everyone falls back to IP, defeating the per-user key.
- Redis store applied in test env - unit tests shouldn't require infra. Gate on `env.NODE_ENV === 'test'`.
- In-memory store on a multi-instance / serverless deploy - counters drift, limits silently become `instanceCount × limit`.
- Emitting legacy `X-RateLimit-*` headers alongside draft-7 - pick one (`standardHeaders: 'draft-7'`, `legacyHeaders: false`).
