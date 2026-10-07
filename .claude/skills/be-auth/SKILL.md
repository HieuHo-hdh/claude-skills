---
name: be-auth
description: Use when wiring authentication into a Node.js backend. Issues JWT access + rotating refresh tokens as HttpOnly cookies, hashes passwords with argon2, mounts /auth routes, and exports a requireAuth middleware. Source of truth for the contract fe-auth consumes.
---

# be-auth

This skill is the **source of truth for the auth contract**. `fe-auth` reads the cookie names, routes, and TTLs defined here. Keep both in sync whenever either changes.

Default: **access JWT (15 min) + rotating opaque refresh token (7-day rolling, 30-day absolute cap)**, both delivered as HttpOnly cookies on `Path=/auth` for refresh and `Path=/` for access.

## Contents

**Setup** - preconditions and shared rules.
- [Prerequisites](#prerequisites) - upstream skills, deps, env slots.
- [Working directory](#working-directory) - target project under `source-code/`.
- [Shared conventions](#shared-conventions) - coding, project structure, API envelope.

**Design** - the shape of the system.
- [Token shape](#token-shape) - access JWT claims, refresh opaque bytes.
- [Cookies](#cookies) - names, flags, paths, TTLs.
- [Password hashing](#password-hashing) - argon2id parameters.
- [Routes](#routes) - the six endpoints and their contracts.
- [Refresh rotation + reuse detection](#refresh-rotation--reuse-detection) - token family revoke.

**Workflow** - what to emit and in what order.
- [1. Install deps](#1-install-deps) - argon2, jsonwebtoken, cookie-parser.
- [2. Env additions](#2-env-additions) - JWT secrets, cookie domain, TTLs.
- [3. DB model](#3-db-model) - `User`, `RefreshToken` (SQL) or embedded (Mongo).
- [4. Service layer](#4-service-layer) - `authService` with register / login / refresh / logout.
- [5. Routes](#5-routes) - mount `/auth` with the six endpoints.
- [6. Middleware](#6-middleware) - `requireAuth`, optional `requireRole`.
- [7. Stub → real swap](#7-stub--real-swap-if-be-boilerplate-stubs-exist) - delete `src/stubs/auth/`.

**I/O & verification** - closing loop.
- [Input](#input) - `be-setup` selections, optional stubs from `be-boilerplate`.
- [Output](#output) - `/auth` routes, middleware, service, DB model.
- [Verification](#verification) - cookie flags, refresh rotation, reuse detection, logout.

## Prerequisites

- **`be-setup` has run** - project scaffolded at `source-code/<project-name>/` with `CLAUDE.md` capturing language, DB, ORM, logger.
- **DB migrations tool available** - Prisma / Drizzle / Mongoose from `be-setup`. This skill adds `User` + `RefreshToken` tables / collections and runs a migration.
- **HTTPS in production** - cookies set `Secure` in prod; local dev uses `Secure: false` behind `NODE_ENV !== 'production'`.

## Working directory

Runs inside `source-code/<project-name>/` - the project scaffolded by `be-setup`. Before writing auth code: confirm the current directory, read that project's `CLAUDE.md` for DB / ORM / logger, and if multiple projects exist under `source-code/`, ask which one first. All generated files go under that project only.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B (inside an existing project).

## Shared conventions

- **Coding conventions:** `.claude/rules/fe-coding-conventions.md` - naming, imports, TS rules, error-handling at boundaries (auth routes are a boundary; validate every input).
- **API envelope:** `.claude/rules/be-response.md`. Auth failures throw `AppError(ERROR_CODES.AUTH_*)`; the shared middleware emits `{ status: 'error', error: { code, message } }`. Never leak internal messages via `overrideMessage`.
- **Project structure:** auth lives across the standard layers - `src/schemas/auth.ts`, `src/services/auth.ts`, `src/controllers/auth.ts`, `src/routes/auth.ts`, `src/middleware/auth.ts`, `src/repositories/user.ts`, `src/repositories/refresh-token.ts` (SQL only).

## Token shape

- **Access** - JWT (HS256), 15 min TTL, claims `{ sub, role, iat, exp }`. `sub` is the user id (string). `role` is `'user' | 'admin'` by default - extend as the app needs.
- **Refresh** - opaque random, 32 bytes from `crypto.randomBytes`, base64url-encoded. Not a JWT. Stored **hashed** in the DB (sha256) so a DB leak does not grant sessions. Rotates on every use. 7-day rolling TTL, 30-day absolute cap from first login.

## Cookies

| Cookie | Content           | Path       | HttpOnly | Secure (prod) | SameSite | TTL     |
| ------ | ----------------- | ---------- | -------- | ------------- | -------- | ------- |
| `at`   | Access JWT        | `/`        | yes      | yes           | Lax      | 15 min  |
| `rt`   | Refresh opaque    | `/auth`    | yes      | yes           | Lax      | 7 days  |

- **Path on `rt` is `/auth`** - the browser only sends it to `/auth/refresh` and `/auth/logout`, not to every API call. Shrinks the CSRF surface.
- **SameSite=Lax** - safe default; the frontend and backend share an eTLD+1. If they do not (cross-site cookies), switch to `SameSite=None; Secure` and add CSRF double-submit.
- **No `Domain` attribute by default** - cookie binds to the exact host. Set `COOKIE_DOMAIN` env (and the `domain` flag) only when subdomain-sharing is required.

## Password hashing

**argon2id** via `argon2`. Memory 19 MiB, iterations 2, parallelism 1 (OWASP 2024 recommendation). Hash on register and on password reset; verify on login.

```ts
import argon2 from 'argon2'
const hash = await argon2.hash(password, { type: argon2.argon2id, memoryCost: 19456, timeCost: 2, parallelism: 1 })
const ok = await argon2.verify(hash, password)
```

Never log passwords, never return hashes in responses, never store plaintext even transiently.

## Routes

Six endpoints under `/auth`. All reject bodies that fail Zod. All responses use the shared error envelope.

| Method | Path                   | Body / cookies in         | Response                                                    |
| ------ | ---------------------- | ------------------------- | ----------------------------------------------------------- |
| POST   | `/auth/register`       | `{ email, password, name }` | Sets `at` + `rt` cookies, 201 `{ user: { id, email, role } }` |
| POST   | `/auth/login`          | `{ email, password }`     | Sets `at` + `rt` cookies, 200 `{ user: { id, email, role } }` |
| POST   | `/auth/refresh`        | Cookie `rt`                | Rotates `rt`, resets `at`, 204                              |
| POST   | `/auth/logout`         | Cookie `rt` (optional)     | Clears both cookies, revokes `rt` row, 204                   |
| POST   | `/auth/forgot-password`| `{ email }`                | 202 always (do not reveal account existence)                 |
| POST   | `/auth/reset-password` | `{ token, newPassword }`   | 204 on success; 400 `InvalidToken` otherwise                 |

**Rate-limit login + forgot-password harder** than the global `express-rate-limit` default. Add a per-route limiter: 5 requests / 15 min per IP for login, 3 / hour per IP for forgot-password.

## Refresh rotation + reuse detection

Every successful `/auth/refresh` call:

1. Hash the incoming `rt` cookie value (sha256).
2. Look up the row by hash. If missing → **reuse detected**: revoke every refresh token in the user's family (same `userId`), clear cookies, return 401.
3. If present and not expired → mark the old row revoked, insert a new row with a fresh opaque token (same family id, new hash), set the new `rt` cookie, mint a new access JWT.
4. If present but expired → clear cookies, return 401.

The **family id** is a UUID stamped at login; every rotation inherits it. Reuse of any revoked token in the family revokes all siblings - this catches a stolen cookie the moment the thief refreshes after the real user has already rotated.

## 1. Install deps

```bash
pnpm add argon2 jsonwebtoken cookie-parser
pnpm add -D @types/jsonwebtoken @types/cookie-parser   # TS only
```

Mount `cookie-parser` in `src/index.ts` **before** route mounts:

```ts
import cookieParser from 'cookie-parser'
app.use(cookieParser())
```

## 2. Env additions

Add to `src/config/env.ts` Zod schema:

```ts
JWT_ACCESS_SECRET: z.string().min(32),
JWT_ACCESS_TTL: z.string().default('15m'),
REFRESH_TTL_DAYS: z.coerce.number().int().positive().default(7),
REFRESH_ABSOLUTE_CAP_DAYS: z.coerce.number().int().positive().default(30),
COOKIE_DOMAIN: z.string().optional(),
```

Append slots to `.env.example` with placeholder values. Generate the secret: `openssl rand -base64 48`.

## 3. DB model

**Prisma** (PostgreSQL):

```prisma
model User {
  id           String   @id @default(cuid())
  email        String   @unique
  passwordHash String
  name         String
  role         String   @default("user")
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt
  refreshTokens RefreshToken[]
}

model RefreshToken {
  id         String   @id @default(cuid())
  userId     String
  user       User     @relation(fields: [userId], references: [id], onDelete: Cascade)
  familyId   String   // UUID shared across one login's rotation chain
  tokenHash  String   @unique  // sha256 of the opaque token
  revokedAt  DateTime?
  expiresAt  DateTime
  createdAt  DateTime @default(now())
  @@index([userId, familyId])
}
```

Then `pnpm exec prisma migrate dev --name auth`.

**Drizzle**: equivalent tables in `src/db/schema.ts`, then `drizzle-kit generate && migrate`.

**Mongoose**: `User` schema with `passwordHash` + `role`; `RefreshToken` as a separate collection with the same fields. Mongoose auto-indexes `tokenHash` (`unique: true`).

**Reset-password token** - a separate `PasswordResetToken` row (userId, tokenHash, expiresAt, consumedAt) with 30 min TTL, single-use. Add it to the same migration.

**Sensitive-field MUST** (`.claude/rules/be-response.md` → *Sensitive fields*): `passwordHash` / `tokenHash` / `resetTokenHash` **never** appear in a response body. Every `userRepo` / `refreshTokenRepo` / `passwordResetTokenRepo` method that returns an entity scopes them out at the ORM. Prisma: `omit: { passwordHash: true }` on every read / write except the two paths that need the hash (`byEmail` / `byEmailWithRole` → login verify, `setPasswordHash` → reset write). Drizzle / Mongoose: explicit `select` list / `.select('-passwordHash')` projection.

## 4. Service layer

`src/services/auth.ts` owns the logic; the controller only translates HTTP ↔ service calls.

```ts
export const authService = {
  async register(input: RegisterInput): Promise<AuthResult> { … },
  async login(input: LoginInput): Promise<AuthResult> { … },
  async refresh(rawRefreshCookie: string): Promise<AuthResult> { … },
  async logout(rawRefreshCookie: string | undefined): Promise<void> { … },
  async forgotPassword(email: string): Promise<void> { … },
  async resetPassword(token: string, newPassword: string): Promise<void> { … },
}

type AuthResult = {
  user: { id: string; email: string; role: string }
  accessToken: string           // controller sets as `at` cookie
  refreshToken: string          // controller sets as `rt` cookie
  refreshExpiresAt: Date
}
```

**Minting helpers** live in `src/lib/tokens.ts`:

- `signAccessToken(user)` → JWT via `jsonwebtoken`.
- `generateRefreshToken()` → `{ raw, hash, familyId }`.
- `hashRefreshToken(raw)` → sha256 hex.
- `verifyAccessToken(jwt)` → throws on invalid / expired.

**Reuse detection** sits inside `authService.refresh`:

```ts
const row = await refreshTokenRepo.findByHash(hashRefreshToken(raw))
if (!row || row.revokedAt) {
  if (row?.revokedAt) await refreshTokenRepo.revokeFamily(row.userId, row.familyId)
  throw new AppError(ERROR_CODES.AUTH_UNAUTHORIZED)
}
if (row.expiresAt < new Date()) throw new AppError(ERROR_CODES.AUTH_UNAUTHORIZED)
```

## 5. Routes

`src/routes/auth.ts`:

```ts
import { Router } from 'express'
import { authController } from '@/controllers/auth'
import { loginLimiter, forgotLimiter } from '@/middleware/auth-rate-limit'

export const authRouter = Router()
authRouter.post('/register', authController.register)
authRouter.post('/login', loginLimiter, authController.login)
authRouter.post('/refresh', authController.refresh)
authRouter.post('/logout', authController.logout)
authRouter.post('/forgot-password', forgotLimiter, authController.forgotPassword)
authRouter.post('/reset-password', authController.resetPassword)
```

Mount in `src/index.ts`:

```ts
import { authRouter } from '@/routes/auth'
app.use('/auth', authRouter)
```

The controller sets cookies via `res.cookie('at', accessToken, cookieOpts('/'))` and `res.cookie('rt', refreshToken, cookieOpts('/auth', refreshExpiresAt))` - helper in `src/lib/cookies.ts` centralizes the flag table above.

## 6. Middleware

`src/middleware/auth.ts`:

```ts
import type { RequestHandler } from 'express'
import { ERROR_CODES } from '@/constants/error-codes'
import { AppError } from '@/lib/app-error'
import { verifyAccessToken } from '@/lib/tokens'

export const requireAuth: RequestHandler = (req, _res, next) => {
  const token = req.cookies?.at ?? extractBearer(req.headers.authorization)
  if (!token) throw new AppError(ERROR_CODES.AUTH_UNAUTHORIZED)
  try {
    req.user = verifyAccessToken(token)
    next()
  } catch {
    throw new AppError(ERROR_CODES.AUTH_UNAUTHORIZED)
  }
}

export const requireRole = (role: string): RequestHandler => (req, _res, next) => {
  if (req.user?.role !== role) throw new AppError(ERROR_CODES.AUTH_FORBIDDEN)
  next()
}
```

**Augment `Express.Request`** in `src/types/express.d.ts`:

```ts
declare global {
  namespace Express {
    interface Request { user?: { sub: string; role: string } }
  }
}
export {}
```

The middleware prefers the cookie (`at`) over `Authorization: Bearer`. Keeping the bearer fallback lets non-browser clients (CI, mobile) call the API without juggling cookies.

## 7. Stub → real swap *(if be-boilerplate stubs exist)*

When replacing stubs with the real implementation:

- [ ] Replace the stub router mount in `src/index.ts` (`stubAuthRouter` → `authRouter`).
- [ ] Replace `src/middleware/auth.ts` contents (stub re-export → real `requireAuth` + `requireRole`).
- [ ] Grep the repo for `stubs/auth` - should be **zero** matches.
- [ ] Delete `src/stubs/auth/`.
- [ ] Re-run `pnpm typecheck`, `pnpm lint`, `pnpm test -- --run`.
- [ ] Update `CLAUDE.md`: auth status → `wired` with the token TTLs and cookie names.

## Input

- `be-setup` selections (language, DB, ORM, logger).
- `be-boilerplate` stubs under `src/stubs/auth/` (optional - only present on the default `be-setup → be-boilerplate → be-auth` flow).

## Output

- `src/routes/auth.ts` + `src/controllers/auth.ts` + `src/services/auth.ts`.
- `src/middleware/auth.ts` (`requireAuth`, `requireRole`).
- `src/middleware/auth-rate-limit.ts` (login + forgot-password limiters).
- `src/lib/tokens.ts` (JWT sign / verify, refresh generate / hash).
- `src/lib/cookies.ts` (shared cookie flag helper).
- `src/repositories/user.ts` (if not already from `be-boilerplate`), `src/repositories/refresh-token.ts` (SQL), `src/repositories/password-reset-token.ts`.
- ORM schema entries + migration for `User`, `RefreshToken`, `PasswordResetToken`.
- `src/types/express.d.ts` augmenting `Request.user`.
- `.env.example` updated with JWT + cookie slots.

## Verification

- [ ] `at` cookie: `HttpOnly`, `SameSite=Lax`, `Path=/`, `Secure` in prod. 15 min expiry.
- [ ] `rt` cookie: `HttpOnly`, `SameSite=Lax`, `Path=/auth`, `Secure` in prod. 7-day expiry.
- [ ] Password hashes are argon2id (`$argon2id$…`), never plaintext in DB or logs.
- [ ] Refresh rotation: a successful `/auth/refresh` revokes the old row and issues a new `rt` with a new hash.
- [ ] Reuse detection: calling `/auth/refresh` twice with the same `rt` cookie → second call 401 **and** every token in the family is revoked (query `RefreshToken` table).
- [ ] Logout: both cookies cleared on the response (`Max-Age=0`), the current `rt` row is revoked.
- [ ] Reset-password token is single-use (`consumedAt` set) and expires at 30 min.
- [ ] `forgot-password` returns 202 regardless of whether the email exists.
- [ ] `requireAuth` 401s without a cookie / bearer; 401s on expired token; passes with a valid access JWT.
- [ ] `requireRole('admin')` 403s a `user`-role token.
- [ ] If `be-boilerplate` ran first: `rg -n 'stubs/auth' src` returns zero matches.
- [ ] E2E: register → login → protected GET → force access expiry (wait or clock-mock) → refresh → protected GET → logout → protected GET 401.

## Recommendations

- Keep the auth service in a single file - do not scatter token minting across controllers.
- Secrets are never read inline (`process.env.JWT_ACCESS_SECRET`) - go through the validated `env` from `src/config/env.ts`.
- `jsonwebtoken` v9+ throws typed errors (`TokenExpiredError`, `JsonWebTokenError`) - map both to 401 and avoid leaking which one it was.
- If the project adds OAuth / SSO later, mount it as a sibling under `/auth/oauth/*` and reuse the same `rt` rotation table - do not fork a second refresh system.
