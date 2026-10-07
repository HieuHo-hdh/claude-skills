# Coding conventions

Shared rule referenced by every `be-*` skill (`be-setup`, `be-boilerplate`, `be-auth`, `be-test`, `be-rate-limit`).

Scope: TypeScript / JavaScript source under `source-code/<project-name>-be/src/`. Deviations: state a reason inline.

## Contents

**Code shape** - how source is named, imported, typed, and commented.
- [Naming](#naming) - case per kind, file-vs-export agreement.
- [Imports](#imports) - order, alias vs relative, named exports.
- [TypeScript](#typescript) - `interface` vs `type`, no `any`, discriminated unions.
- [Comments](#comments) - default is none; explain *why*, not *what*.

**Layering** - which layer may touch which, and what the direction of imports looks like.
- [Layer map](#layer-map) - `routes → controllers → services → repositories → lib`.
- [Controller rules](#controller-rules) - parse, call service, send response; no `try/catch`.
- [Service rules](#service-rules) - business logic; throw `AppError`; no `req` / `res`.
- [Repository rules](#repository-rules) - only place that imports the DB client.
- [Schema rules](#schema-rules) - Zod schemas hoisted; inferred types co-exported.

**Runtime behavior** - how the app handles config, errors, async, and logging.
- [Config and env](#config-and-env) - `env` is imported, never read raw.
- [Error handling](#error-handling) - throw `AppError`; let Zod throw; middleware owns the envelope.
- [Async & promises](#async--promises) - `async / await`, no silent swallow.
- [Logging](#logging) - pino, structured, redact secrets.
- [Security](#security) - what never leaves the service.

**Dependencies** - how packages enter the project.
- [Dependency hygiene](#dependency-hygiene) - pin versions, no deprecated APIs.

**Hygiene** - keeping the codebase clean.
- [Dead code](#dead-code) - delete on sight, git remembers.
- [Formatting](#formatting) - Prettier owns it, never argue.
- [Linting](#linting) - project lint config is the source of truth.

**Anti-patterns**
- [Anti-patterns - reject on sight](#anti-patterns---reject-on-sight)

## Naming

| Kind                          | Case             | Example                                       |
| ----------------------------- | ---------------- | --------------------------------------------- |
| Source file                   | kebab-case       | `user.ts`, `error-handler.ts`, `app-error.ts` |
| Resource folder               | kebab-case       | `routes/user.ts`, `controllers/role.ts`       |
| Function                      | camelCase        | `fetchUsers`, `buildPagination`               |
| Class / type / interface      | PascalCase       | `AppError`, `UserRepo`, `AsyncStatus`         |
| Constant (module-level)       | SCREAMING_SNAKE  | `ERROR_CODES`, `AT_COOKIE`                    |
| Error code value              | SCREAMING_SNAKE  | `AUTH_INVALID_CREDENTIALS`, `RATE_LIMITED`    |
| Enum / string-union values    | kebab or SCREAM  | `'sign-in'` for inputs; `'AUTHENTICATED'` for machine states |
| Boolean variable              | positive `isX / hasX` | `isActive`, `hasAccess`                  |
| Zod schema                    | `<entity><action>Schema` | `userCreateSchema`, `loginSchema`     |
| Repo / service / controller object | `<entity>Repo` / `<entity>Service` / `<entity>Controller` | `userRepo.list`, `userService.get`, `userController.create` |

**Do not** use file names that disagree with their main export (`src/services/user.ts` must export `userService`), abbreviations that are not universal (`usr`, `ctrl`), or Hungarian prefixes (`strEmail`).

## Imports

Order - separated by blank lines, enforced by `eslint-plugin-import`:

1. Node built-ins (`node:*`, `fs`, `path`, `crypto`).
2. External packages (`express`, `zod`, `argon2`, `prisma`).
3. Internal via alias (`@/config/*`, `@/lib/*`, `@/services/*`).
4. Relative siblings (`./x`, `../y`) - only inside `__tests__/` to reach the file under test, or inside a resource folder for colocated helpers.

**Use `@/*` for cross-directory imports; use `./` or `../` only inside the same folder (or `__tests__/` reaching back one level).** Named exports everywhere - default exports are reserved for `src/index.ts`.

## TypeScript

- **`interface` for public, extensible object shapes.** **`type` for unions, intersections, utility-derived aliases.**
- **Never use `any`.** Use `unknown` at boundaries, narrow with a type guard or Zod. If a third-party gap forces `any`, leave a one-line comment explaining why.
- **Discriminated unions over optional-prop soup.** `ApiResponse<T>` is `SuccessResponse<T> | ErrorResponse`, not one interface with everything optional.
- **`readonly` on inputs you do not mutate** - especially arrays and objects passed into services.
- **No non-null assertions (`x!`) in application code.** Narrow with a check or throw `AppError` explicitly.
- **Enum → string-literal unions.** `type Role = 'admin' | 'user' | 'guest'` beats `enum Role { ... }` for tree-shakability and JSON compatibility.
- **`satisfies` for config / registry objects** (`ERROR_MESSAGES satisfies Record<ErrorCode, ErrorSpec>`) - keeps literal narrowing while checking the shape.
- **Infer from Zod, do not duplicate.** `type UserCreateInput = z.infer<typeof userCreateSchema>` - one source of truth.

## Comments

Default: **no comment.** Add one only when the *why* is non-obvious:

- Hidden constraint (`// Prisma returns `null` when soft-deleted — treat as not found`).
- Subtle invariant (`// refresh token family is single-use; reuse detection fires on second hit`).
- Workaround for a specific upstream bug - link the issue.
- `// TODO(#123)` / `// FIXME(@owner)` for tracked deferred work - include a link or owner and the next action. A TODO with no link and no next action is dead code - delete it.

**Do not** write comments that explain *what* the code does when the identifier already does that. Do not reference the current task, PR, or callers (`// used by /auth/login`) - those rot and belong in the PR description.

One line max on internal helpers. If a public helper needs more, extract the docs to a dedicated `README.md` in the lib folder.

## Layer map

Imports point **down** the table. A row never imports from a row above it.

| Layer           | May import                                                       | Must not import                                   |
| --------------- | ---------------------------------------------------------------- | ------------------------------------------------- |
| `routes/`       | `controllers`, `middleware`                                       | `services`, `repositories`                        |
| `controllers/`  | `services`, `schemas`, `lib`, `middleware` (types only)           | `repositories`, `routes`                          |
| `services/`     | `repositories`, `schemas`, `lib`, `constants`                     | `controllers`, `routes`, `middleware`, `req`/`res` types |
| `repositories/` | `@/lib/prisma` (or the chosen DB client), `schemas` (types only)  | `services`, `controllers`, `routes`               |
| `middleware/`   | `lib`, `constants`                                                | `services`, `repositories` (except where auth-related, which is itself a service boundary that lives in `middleware/auth.ts`) |
| `schemas/`      | `zod`, other `schemas` (types only)                               | everything else                                   |
| `lib/`          | external packages, `config`                                       | `services`, `repositories`, `controllers`         |
| `config/`       | `zod`, `dotenv`                                                   | everything else                                   |

## Controller rules

- **Parse `req` → call service → send response.** Three lines in the common case.
- **No `try/catch`.** The error middleware already converts `AppError` + `ZodError` + `unknown` to the envelope. Catching inside the controller hides bugs.
- **Use `sendOk` / `sendCreated` from `@/lib/response`** - never hand-build `{ status: 'success', data }`.
- **No business logic** - a `if (!user.isAdmin) throw ...` belongs in the service, not the controller.
- **No DB client import.** Services and repos own that.

```ts
// ✅ shape
create: async (req: Request, res: Response) => {
  const body = userCreateSchema.parse(req.body)
  sendCreated(res, await userService.create(body))
}
```

## Service rules

- **No `req` / `res`.** A service's inputs are already-parsed values; its output is a plain object or throws `AppError`.
- **Throw `AppError(ERROR_CODES.X, detail?)`.** Never `throw new Error('invalid email')` - the error middleware can't map a bare `Error` to a code.
- **Business logic lives here** - uniqueness checks, authorization checks, cross-entity invariants.
- **One service per entity.** Cross-entity work goes in whichever service "owns" the primary action (`authService.register` writes to `userRepo` and `refreshTokenRepo`).
- **No `console.log`.** Import `logger` from `@/lib/logger` and emit structured logs: `logger.info({ userId }, 'user created')`.

## Repository rules

- **Only `src/repositories/*` and `src/lib/prisma.ts` import the DB client.** Nothing else, ever.
- **No business logic** - repo methods return rows or `null`. Policy decisions (`throw NOT_FOUND if missing`) belong in the service.
- **Sensitive-field omit at the query** - every read / write that doesn't need the hash sets `omit: { passwordHash: true }` (Prisma) or an explicit `select` (Drizzle / Mongoose). Repo methods that *do* need the hash (`byEmailWithPasswordHash`, `setPasswordHash`) are named explicitly so grepping finds every sensitive-data path.
- **One method, one query.** Prefer `prisma.$transaction([...])` over multiple round-trips. Services compose transactions; repos do not.

## Schema rules

- **One file per domain.** `src/schemas/user.ts` holds `userCreateSchema`, `userUpdateSchema`, inferred types.
- **Hoist to module scope.** Zod schemas are compiled once at import time - defining `z.object({ ... })` inside a controller is a hot-path waste.
- **Co-export inferred types.** `export type UserCreateInput = z.infer<typeof userCreateSchema>` so services and controllers share one source.
- **`strict()` or `passthrough()` is a design decision** - default is implicit strip (drop unknown keys). If an endpoint accepts arbitrary metadata, state the choice inline with `// passthrough: accepts untyped metadata on purpose`.

## Config and env

- **`src/config/env.ts` is the only file that reads `process.env`.** Everything else imports `env`.
- **Zod-parse at boot.** Invalid env causes `process.exit(1)` with a readable error - no `env.FOO ?? 'default'` scattered across call sites.
- **Required vs optional** - secrets (`JWT_ACCESS_SECRET`) are required; infrastructure URLs with safe local defaults (`REDIS_URL`) can carry `.default('redis://localhost:6379')`.
- **Boolean flags** - parse with `z.coerce.boolean()` or an explicit `z.enum(['true','false']).transform(v => v === 'true')`. Env values are strings; a raw `env.FLAG === true` is always `false`.

## Error handling

- **Validate at system boundaries only** - user input (Zod at the controller edge), external APIs, environment. Trust internal code.
- **Do not catch what you cannot handle.** `try { ... } catch (e) { logger.error(e) }` is not error handling - the error middleware already logs and converts. If a specific recovery is required (e.g. a race-condition retry), catch narrowly and either re-throw an `AppError` or return a typed result.
- **Errors flow up.** Services throw, controllers do not catch, middleware converts. Every path through the app has exactly one error exit point.
- **Do not add fallback values for scenarios that can't happen.** A required env var is not "maybe missing" after `env.ts` passed. A required Zod field is not "possibly undefined" after `parse`.

## Async & promises

- **Prefer `async / await`** over `.then` chains. Reserve chaining for compositional cases (`Promise.all`, chained `.map`).
- **Every `await` sits inside an async function** that is reachable by the error middleware (controller handler, mounted hook, startup script).
- **Never swallow rejections.** No bare `.catch(() => {})`. If a background task can fail silently, log it and surface a metric; a swallowed error is a latent incident.
- **`Promise.all` for independent reads.** Serial awaits for independent queries double latency - `await Promise.all([userRepo.byId(id), roleRepo.list()])`.

## Logging

- **Use `logger` from `@/lib/logger` (pino).** No `console.log` / `console.error` in committed code.
- **Structured first.** `logger.info({ userId, requestId }, 'user updated')` - message is a label, data is a payload. Grep + Loki / Datadog can filter on the payload.
- **Redact at the logger** - `redact: ['req.headers.authorization', 'req.headers.cookie', '*.password', '*.passwordHash', '*.token*']` in the pino config. Never trust individual log sites to remember.
- **Request-scoped correlation.** `pino-http` already attaches `req.id`; services receive it via a param or AsyncLocalStorage - do not stuff it into globals.
- **Levels:** `debug` for noisy local-only chatter, `info` for business events (user created, token refreshed), `warn` for recoverable anomalies (retrying external call), `error` for faults that need a human. `error` lines are the on-call signal - do not fire them for expected 4xx responses.

## Security

- **MUST never return** `password`, `passwordHash`, `tokenHash`, `resetTokenHash`, API keys, or private keys in a response body. Enforce at the repo via `omit` / `select`, not downstream.
- **Tokens never enter state** - access tokens live in HttpOnly cookies, refresh tokens are opaque + rotated, no token ever appears in a log line (redact rule above covers it).
- **Password hashing** - argon2id with the project's calibrated cost params; services always `verify` through a dedicated repo method, never read the hash out and compare raw.
- **CORS allowlist is explicit** - no `cors()` with no options in production. Development may run open; `env.CORS_ORIGIN` gates it.
- **Cookies: `HttpOnly`, `SameSite=Lax` (or `Strict`), `Secure` in prod.** Set once in `@/lib/cookies.ts` and import; never hand-roll per route.
- **Rate limiting at system boundaries** - follow `be-rate-limit`. Global by IP, per-user after `requireAuth`, auth-sensitive on `/auth/{login,forgot-password}`.

## Dependency hygiene

- **Pin exact versions** at install (`--save-exact`). The lock file is secondary - the `package.json` range should pin, not caret.
- **Audit on install.** `pnpm audit --prod` on every dependency bump; fix or document the exception in `CLAUDE.md`.
- **No deprecated / unmaintained packages.** If a dependency has not shipped in >24 months and has an active fork, prefer the fork.
- **Dev vs prod split.** Testing / build tooling lives in `devDependencies`. A `vitest` leak into `dependencies` ships megabytes to prod.
- **Avoid single-maintainer micro-packages** for anything in the auth / crypto / env path - pin to vetted libraries only (`argon2`, `jsonwebtoken`, `zod`, `pino`).

## Dead code

Delete on sight. No `// removed`, no commented-out blocks, no "`unused_` for later" exports. Git remembers.

## Formatting

Prettier owns formatting. Never argue. Never add manual line-breaks that Prettier will undo. If a Prettier default is wrong, change the config once - do not fight it per-file. Keep import-order enforcement wired via `eslint-plugin-import` so order drift is a lint error, not a review conversation.

## Linting

The project's ESLint flat config is the source of truth. `pnpm lint` passes before every commit. Do not add `// eslint-disable-*` to silence a real error - fix the code or, if the rule is wrong for the codebase, adjust the rule globally.

## Anti-patterns - reject on sight

- `try/catch` around a service call in the controller - the error middleware already handles everything.
- Hand-building `{ status: 'error', ... }` in a controller or service - throw `AppError` and let the middleware emit it.
- A repo method returning a user / token entity without `omit`-ing the hash - the one path through login is the exception, everything else leaks.
- `process.env.X` read anywhere outside `src/config/env.ts` - import `env`.
- DB client (`prisma`, `drizzle`) imported from a service or controller - route all DB access through `src/repositories/*`.
- `any` in application code with no comment - use `unknown` + narrow.
- `console.log` left in a commit - use `logger` or delete.
- Zod schemas re-derived inside a controller function body - hoist to module scope.
- A new resource that invents its own list envelope (`{ data: { rows, cursor } }`) when the project already has one - converge on `data: []` + `meta.pagination` (see `be-response.md`).
- Caret ranges (`^1.2.3`) in `package.json` after `be-setup` set it up with pinned versions - either everyone pins or no one does.
- A fetch call inside a route handler file - put it in a service and let the controller call the service.
- `Error` or `Date` instances leaked into a logger payload - stringify at the boundary; pino prefers plain data.
- A middleware that silently mutates `req.body` after Zod parsed it - subsequent controllers see a different shape than their types promise.
- A rate limiter mounted before `requireAuth` keyed on `req.user?.sub ?? req.ip` - `req.user` is `undefined` here, every authenticated user shares an IP bucket.
